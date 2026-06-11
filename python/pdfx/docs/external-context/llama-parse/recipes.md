---
title: Recipes | Developer Documentation
description: Short, copy-pasteable Parse snippets for common workflows — retries, S3 uploads, webhooks, multi-language OCR, page ranges, pandas tables, multimodal screenshots.
---

**Short, copy-pasteable snippets for the patterns Parse users hit most often.** Each recipe is \~10-20 lines and answers a specific “how do I do X?” question. Drop them into your project and adapt as needed.

For full walk-throughs, see the [Parse Examples](/llamaparse/parse/examples/index.md) tutorials. For the full API reference, see the [REST API Guide](/llamaparse/parse/guides/api-reference/index.md).

All recipes assume:

```
from llama_cloud import LlamaCloud
client = LlamaCloud(api_key="llx-...")  # or set LLAMA_CLOUD_API_KEY in your env
```

## Parse a document end-to-end

The bare minimum: upload a file, parse it, print the markdown.

```
file = client.files.create(file="doc.pdf", purpose="parse")
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown"],
)
print(result.markdown.pages[0].markdown)
```

## Pin a version for production

Use a dated `version` so model updates can’t change your output without your knowledge.

```
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="2026-04-06",  # pin a specific date
    expand=["markdown"],
)
```

See [Tiers → Versioning and reproducibility](/llamaparse/parse/guides/tiers/#versioning-and-reproducibility/index.md) for the latest available dates.

## Parse only specific pages

Skip irrelevant pages and save credits.

```
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    page_ranges={"target_pages": "1,3,5-10"},  # 1-indexed
    expand=["markdown"],
)
```

You can also cap the total with `{"max_pages": 10}`.

## Crop headers and footers from every page

Strip a fixed margin off the top and bottom of every page before parsing.

```
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    crop_box={"top": 0.08, "bottom": 0.08, "left": 0, "right": 0},
    expand=["markdown"],
)
```

Values are page-height/width ratios (0.0–1.0).

## Multi-language OCR

Hint the OCR engine for non-English documents.

```
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    processing_options={
        "ocr_parameters": {"languages": ["en", "fr", "de"]},
    },
    expand=["markdown"],
)
```

## Save money on long mixed-complexity documents

Enable Cost Optimizer to route simple pages to `cost_effective` automatically.

```
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic_plus",
    version="latest",
    processing_options={
        "cost_optimizer": {"enable": True},
    },
    expand=["markdown", "metadata"],
)


# See which pages got the cheaper tier
for page in result.metadata.pages:
    flag = "cost-optimized" if page.cost_optimized else "premium"
    print(f"page {page.page_number}: {flag}")
```

See [Cost Optimizer](/llamaparse/parse/guides/configuring-parse/#cost-optimizer/index.md).

## Steer the parser with a custom prompt

Tell the agentic model what to focus on.

```
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    agentic_options={
        "custom_prompt": "This is a financial 10-K. Preserve currency symbols on every number and keep the original section hierarchy.",
    },
    expand=["markdown"],
)
```

See [Custom Prompt](/llamaparse/parse/guides/configuring-parse/#custom-prompt/index.md) for prompt-engineering tips.

## Extract a table into pandas

Get structured items, walk for tables, load into a dataframe.

```
import io
import pandas as pd


result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["items"],
)


# Find the first table on page 3 and load it
page = result.items.pages[2]  # 0-indexed in the items tree
table = next(item for item in page.items if getattr(item, "type", None) == "table")


df = pd.read_csv(io.StringIO(table.csv))
print(df.head())
```

For an end-to-end version with charts, see the [Parse Charts in PDFs and Analyze with Pandas](/llamaparse/parse/examples/parse_charts_pandas/index.md) tutorial.

## Get per-page screenshots for a multimodal pipeline

Save full-page screenshots and download them via presigned URLs.

```
import requests


result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    output_options={"images_to_save": ["screenshot"]},
    expand=["markdown", "images_content_metadata"],
)


# Markdown for the LLM
markdown_blob = "\n\n".join(p.markdown for p in result.markdown.pages)


# Download every screenshot
for image in result.images_content_metadata.images:
    img_bytes = requests.get(image.presigned_url).content
    with open(image.filename, "wb") as f:
        f.write(img_bytes)
```

## Push results to a webhook instead of polling

For long-running jobs, let Parse call you back when the job finishes.

```
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic_plus",
    version="latest",
    webhook_configurations=[
        {
            "webhook_url": "https://your-app.com/parse-callback",
            "webhook_headers": {"X-My-Auth": "secret"},
        }
    ],
)
print(f"Job started: {result.job.id}")
```

When the job finishes, Parse POSTs an event notification to your URL. See [Webhook Configurations](/llamaparse/parse/guides/configuring-parse/#webhook-configurations/index.md).

## Retrieve results later (without re-parsing)

Run the job once, fetch additional fields later by `job_id`.

```
# Step 1 — parse with a minimal expand
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown"],
)
job_id = result.job.id


# Step 2 — later, in another script, get the items tree for the same job
items_result = client.parsing.get(job_id=job_id, expand=["items"])
for page in items_result.items.pages:
    print(f"page {page.page_number}: {len(page.items)} items")
```

See [Retrieving Results](/llamaparse/parse/guides/retrieving-results/index.md) for every legal `expand` value.

## Retry a failing job on a smaller tier

If a parse job fails on `agentic_plus` (e.g. for an unusual layout), retry on `agentic` and inspect.

```
def parse_with_fallback(file_id):
    for tier in ["agentic_plus", "agentic", "cost_effective"]:
        try:
            return client.parsing.parse(
                file_id=file_id,
                tier=tier,
                version="latest",
                expand=["markdown"],
            )
        except Exception as e:
            print(f"tier {tier} failed: {e}")
    raise RuntimeError("all tiers failed")


result = parse_with_fallback(file.id)
```

## Disable cache for a fresh parse

Skip cached results when you need a deterministic re-parse (e.g. after a tier version change).

```
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="2026-04-06",
    disable_cache=True,
    expand=["markdown"],
)
```

See [Cache Control](/llamaparse/parse/guides/configuring-parse/#cache-control/index.md).

## See also

- [Parse Examples](/llamaparse/parse/examples/index.md) — full walk-throughs of these patterns
- [Configuration Model](/llamaparse/parse/guides/configuring-parse/index.md) — where every option lives in the request shape
- [API reference: Parse File](https://developers.llamaindex.ai/reference/resources/parsing/methods/create) — full field-by-field listing of every option
- [Retrieving Results](/llamaparse/parse/guides/retrieving-results/index.md) — every legal `expand` value
