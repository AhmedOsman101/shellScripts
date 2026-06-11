---
title: Getting Started | Developer Documentation
description: Quick start guide for Parse, covering API key generation and document parsing using Python, TypeScript, the REST API, or the Web UI.
---

Using a coding agent?

Give your AI agent access to these docs: `claude mcp add llama-index-docs --transport http https://developers.llamaindex.ai/mcp` — [More options](/python/shared/mcp/index.md)

Get your first parse job running in under a minute—whether you prefer Python, TypeScript, the REST API, or the Web UI.

## Before you begin

You'll need a LlamaCloud API key. [**Get your API key →**](/llamaparse/general/api_key/index.md)

Set it as an environment variable so the SDKs pick it up automatically:

Terminal window

```
export LLAMA_CLOUD_API_KEY="llx-..."
```

## Your first parse job in 60 seconds

- [Python](#tab-panel-42)
- [TypeScript](#tab-panel-43)
- [REST API](#tab-panel-44)
- [Web UI](#tab-panel-45)

Install the SDK:

Terminal window

```
pip install llama-cloud>=2.1
```

Parse a document:

```
from llama_cloud import LlamaCloud


client = LlamaCloud()  # reads LLAMA_CLOUD_API_KEY from the environment


# Upload and parse a document
file = client.files.create(file="./attention_is_all_you_need.pdf", purpose="parse")
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown"],
)


# Print the markdown for the first page
print(result.markdown.pages[0].markdown)
```

That’s it. The SDK handles job polling for you—`client.parsing.parse()` blocks until the job finishes and returns the full result.

Prefer async? Swap `LlamaCloud` for `AsyncLlamaCloud` and `await` the calls:

```
from llama_cloud import AsyncLlamaCloud
import asyncio


async def main():
    client = AsyncLlamaCloud()
    file = await client.files.create(file="./attention_is_all_you_need.pdf", purpose="parse")
    result = await client.parsing.parse(file_id=file.id, tier="agentic", version="latest", expand=["markdown"])
    print(result.markdown.pages[0].markdown)


asyncio.run(main())
```

### Configure your parse job

The snippet above uses defaults. When you’re ready to tune the output, add `input_options`, `output_options`, or `processing_options`:

```
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    output_options={
        "markdown": {"tables": {"output_tables_as_markdown": True}},
        "images_to_save": ["screenshot"],
    },
    processing_options={
        "ocr_parameters": {"languages": ["en"]},
    },
    expand=["text", "markdown", "items", "images_content_metadata"],
)
```

Each group has a dedicated reference page:

- [Input Options](/llamaparse/parse/guides/configuring-parse/#input-options/index.md) — page ranges, crop boxes, file-type-specific controls, and cache behavior
- [Output Options](/llamaparse/parse/guides/configuring-parse/#output-options/index.md) — markdown styling, spatial text, screenshots, tables-as-spreadsheet, and more
- [Processing Options](/llamaparse/parse/guides/configuring-parse/#processing-options/index.md) — OCR languages, ignore rules, chart parsing, cost optimizer
- [Retrieving Results](/llamaparse/parse/guides/retrieving-results/index.md) — every `expand` value and how to control what comes back

Install the SDK:

Terminal window

```
npm install @llamaindex/llama-cloud
```

Create a `parse.ts` file:

```
import LlamaCloud from '@llamaindex/llama-cloud';
import fs from 'fs';


const client = new LlamaCloud(); // reads LLAMA_CLOUD_API_KEY from the environment


// Upload and parse a document
const file = await client.files.create({
  file: fs.createReadStream('./attention_is_all_you_need.pdf'),
  purpose: 'parse',
});


const result = await client.parsing.parse({
  file_id: file.id,
  tier: 'agentic',
  version: 'latest',
  expand: ['markdown'],
});


// Print the markdown for the first page
console.log(result.markdown.pages[0].markdown);
```

Run it:

Terminal window

```
npx tsx parse.ts
```

The SDK handles job polling for you—`client.parsing.parse()` awaits until the job finishes and returns the full result.

### Configure your parse job

Pass `input_options`, `output_options`, or `processing_options` to tune the output:

```
const result = await client.parsing.parse({
  file_id: file.id,
  tier: 'agentic',
  version: 'latest',
  output_options: {
    markdown: { tables: { output_tables_as_markdown: true } },
    images_to_save: ['screenshot'],
  },
  processing_options: {
    ocr_parameters: { languages: ['en'] },
  },
  expand: ['text', 'markdown', 'items', 'images_content_metadata'],
});
```

See the dedicated reference pages for the full set of options:

- [Input Options](/llamaparse/parse/guides/configuring-parse/#input-options/index.md)
- [Output Options](/llamaparse/parse/guides/configuring-parse/#output-options/index.md)
- [Processing Options](/llamaparse/parse/guides/configuring-parse/#processing-options/index.md)
- [Retrieving Results](/llamaparse/parse/guides/retrieving-results/index.md) — every `expand` value and how to control what comes back

If you’d prefer to skip the SDKs, the REST API lets you parse from any environment. Unlike the SDKs, the raw API is asynchronous: you upload a file, kick off a parse job, then poll for the result.

#### 1. Upload a file

Terminal window

```
curl -X POST \
  https://api.cloud.llamaindex.ai/api/v1/files/ \
  -H 'Accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -H "Authorization: Bearer $LLAMA_CLOUD_API_KEY" \
  -F 'file=@/path/to/your/file.pdf;type=application/pdf'
```

Grab the `id` from the response:

```
{
  "id": "cafe1337-e0dd-4762-b5f5-769fef112558"
}
```

#### 2. Start a parse job

Terminal window

```
curl -X POST \
  'https://api.cloud.llamaindex.ai/api/v2/parse' \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $LLAMA_CLOUD_API_KEY" \
  --data '{
    "file_id": "<file_id>",
    "tier": "agentic",
    "version": "latest"
  }'
```

You’ll get a `job_id` back:

```
{
  "id": "c0defee1-76a0-42c3-bbed-094e4566b762",
  "status": "PENDING"
}
```

#### 3. Poll for the result

Call the result endpoint with your `job_id`. The `job.status` field will be `PENDING`, `RUNNING`, `COMPLETED`, or `FAILED`. Keep polling until you see `COMPLETED`, then use `expand` to request the fields you want:

Terminal window

```
curl -X GET \
  'https://api.cloud.llamaindex.ai/api/v2/parse/<job_id>?expand=markdown' \
  -H 'Accept: application/json' \
  -H "Authorization: Bearer $LLAMA_CLOUD_API_KEY"
```

See [Retrieving Results](/llamaparse/parse/guides/retrieving-results/index.md) for every available `expand` value.

If you’re non-technical or just want to sandbox Parse before writing any code, the Web UI is the fastest path.

![Parse Web UI upload view: llama.pdf loaded in the file list on the left, tier picker on the right with Agentic selected, and Advanced options showing input controls like page ranges and cache control.](/_astro/web_ui_upload.DOzzn4mL_TpQQa.png)

1. Go to [**cloud.llamaindex.ai/parse**](https://cloud.llamaindex.ai/parse)
2. Pick a **Tier** from **Recommended Settings**, or switch to **Advanced Settings** to customize
3. Upload your document (or pick one of the sample use cases to try Parse without uploading anything)
4. Click **Run Parse** and view the results directly in the browser

![Parse Web UI result view: the raw LLaMA paper PDF on the left and Parse's clean markdown output on the right, with headings, author block, and the abstract rendered in proper structure.](/_astro/web_ui_result.xa7mL4CM_119HLa.png)

### Choosing a tier

Parse offers four tiers:

- [**Agentic Plus**](/llamaparse/parse/guides/tiers/#agentic-plus/index.md) — state-of-the-art models for maximum accuracy on the hardest documents (complex tables, dense charts, multi-column layouts).
- [**Agentic**](/llamaparse/parse/guides/tiers/#agentic/index.md) — advanced parsing agents for visually rich documents; a strong default for most workloads.
- [**Cost Effective**](/llamaparse/parse/guides/tiers/#cost-effective/index.md) — balanced performance and cost for text-heavy documents with minimal visual structure.
- [**Fast**](/llamaparse/parse/guides/tiers/#fast/index.md) — the lowest-latency, lowest-cost tier for plain-text documents at high volume. Returns text and spatial text only — does not support markdown output.

## Alternative: use a coding agent

If you’re already using Claude Code, Cursor, or another coding agent, you can skip the SDK entirely. Install the Parse agent skill and your agent can parse documents on the fly:

Terminal window

```
npx skills add run-llama/llamaparse-agent-skills --skill llamaparse
```

Then just ask your agent things like:

- _“Parse this PDF and extract the text as markdown.”_
- _“Extract every table from each invoice in `./invoices` and save them as CSVs.”_
- _“Parse this financial report with cost optimizer enabled.”_

The agent writes the SDK calls for you. It picks the right tier, configures options, and saves output — without you needing to remember API details.

**Requirements:** Node 18+, `LLAMA_CLOUD_API_KEY` in the environment, and a coding agent that supports [Vercel-style skills](https://skills.sh).

Two skills are available:

| Skill            | What it does                                                                  |
| ---------------- | ----------------------------------------------------------------------------- |
| **`llamaparse`** | Full parsing via the LlamaCloud API — charts, tables, images, complex layouts |
| **`liteparse`**  | Local-first, no API key needed — best for plain text and simple layouts       |

Install both with `npx skills add run-llama/llamaparse-agent-skills` (no `--skill` flag). [Source on GitHub →](https://github.com/run-llama/llamaparse-agent-skills)

Troubleshooting

If the agent doesn’t see the skill: (1) run the install in the project root, (2) restart the agent session, (3) confirm `LLAMA_CLOUD_API_KEY` is set in the agent’s process environment.

## Next steps

- **Choose the right tier** → [Tiers](/llamaparse/parse/guides/tiers/index.md) explains when to use Agentic Plus vs. Agentic vs. Cost Effective vs. Fast.
- **Learn to configure options** → [Configuring Parse](/llamaparse/parse/guides/configuring-parse/index.md) covers every knob — input, output, and processing options.
- **Save money on long documents** → [Cost Optimizer](/llamaparse/parse/guides/configuring-parse/#cost-optimizer/index.md) routes each page to the right tier automatically.
- **See real examples** → [Parse Examples](/llamaparse/parse/examples/index.md) — runnable tutorials for common use cases.

## Resources

- [Pricing & credits](/llamaparse/general/pricing/index.md)
- Need structured data instead of markdown? Check out [LlamaExtract](/llamaparse/extract/index.md).
