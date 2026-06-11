---
title: Retrieving Results | Developer Documentation
description: Use the expand parameter to control what comes back from a parse job — text, markdown, items, metadata, full files, or presigned download URLs.
---

**`expand` controls what comes back from a parse job.** By default, the API returns only job metadata (status, ID, error messages) — no parsed content. You add `expand` values to opt in to the data you actually want.

This page explains how `expand` works, lists every legal value, and shows the common patterns most callers use.

## Quick lookup

### Inline content

These return parsed data directly in the response body — no extra download step.

| Value           | What you get                                                        | Tier limits   |
| --------------- | ------------------------------------------------------------------- | ------------- |
| `markdown`      | Markdown per page (preserves headings, tables, structure)           | Not on `fast` |
| `markdown_full` | Full markdown for the whole document as a single string             | Not on `fast` |
| `text`          | Plain text per page                                                 | All tiers     |
| `text_full`     | Full plain text for the whole document as a single string           | All tiers     |
| `items`         | Structured items tree per page (tables, headings, figures, etc.)    | Not on `fast` |
| `metadata`      | Per-page metadata (confidence, speaker notes, cost-optimizer flags) | All tiers     |
| `job_metadata`  | Job-level processing details (timing, configuration echo)           | All tiers     |

### Download URLs

These return presigned S3 download URLs instead of the content itself. Use when the result is large and you want to defer or stream the download.

| Value                                    | What you get                                                                  | Tier limits                                                                                                                                |
| ---------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `markdown_content_metadata`              | Download URL for `.md`                                                        | Not on `fast`                                                                                                                              |
| `markdown_full_content_metadata`         | Download URL for the full markdown file                                       | Not on `fast`                                                                                                                              |
| `text_content_metadata`                  | Download URL for `.txt`                                                       | All tiers                                                                                                                                  |
| `text_full_content_metadata`             | Download URL for the full plain text file                                     | All tiers                                                                                                                                  |
| `items_content_metadata`                 | Download URL for items `.json`                                                | Not on `fast`                                                                                                                              |
| `metadata_content_metadata`              | Download URL for metadata `.json`                                             | All tiers                                                                                                                                  |
| `images_content_metadata`                | List of all extracted images with per-image download URLs                     | Requires `images_to_save` to be set                                                                                                        |
| `xlsx_content_metadata`                  | Download URL for the tables-as-spreadsheet `.xlsx`                            | Requires `tables_as_spreadsheet.enable: true`                                                                                              |
| `output_pdf_content_metadata`            | Download URL for the rendered output PDF                                      | All tiers                                                                                                                                  |
| `result_content_metadata.grounded_items` | Download URL for the grounded-items JSONL sidecar (word / line / cell bboxes) | Auto-included when [`granular_bboxes`](/llamaparse/parse/guides/configuring-parse/#granular-bounding-boxes/index.md) is set; not on `fast` |

The difference between these two groups is explained in detail below in [Content fields vs. metadata fields](#content-fields-vs-metadata-fields).

## Common patterns

### Just give me the markdown

The simplest pattern. Most LLM pipelines only need this.

- [Python](#tab-panel-186)
- [TypeScript](#tab-panel-187)

```
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown"],
)


for page in result.markdown.pages:
    print(page.markdown)
```

```
const result = await client.parsing.parse({
  file_id: file.id,
  tier: "agentic",
  version: "latest",
  expand: ["markdown"],
});


for (const page of result.markdown.pages) {
  console.log(page.markdown);
}
```

Don't need per-page markdown?

If you just want the full document as one string, use `expand=["markdown_full"]` instead — it returns `result.markdown_full` directly and avoids the per-page loop.

### Markdown plus the structured items tree

For pipelines that need programmatic access to tables, headings, and figures. Items already include an `md` field per element, so you can build LLM input from items alone — but requesting `markdown` alongside gives you a ready-made per-page markdown string without having to reassemble it from items.

- [Python](#tab-panel-188)
- [TypeScript](#tab-panel-189)

```
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown", "items"],
)


# Per-page markdown for the LLM (or use markdown_full for a single string)
llm_input = "\n\n".join(p.markdown for p in result.markdown.pages)


# Walk the items tree for tables
for page in result.items.pages:
    for item in page.items:
        if hasattr(item, "type") and item.type == "table":
            print(f"Table on page {page.page_number}: {len(item.rows)} rows")
```

```
const result = await client.parsing.parse({
  file_id: file.id,
  tier: "agentic",
  version: "latest",
  expand: ["markdown", "items"],
});


const llmInput = result.markdown.pages.map(p => p.markdown).join("\n\n");


for (const page of result.items.pages) {
  for (const item of page.items) {
    if ("type" in item && item.type === "table" && "rows" in item) {
      console.log(`Table on page ${page.page_number}: ${item.rows.length} rows`);
    }
  }
}
```

### Full markdown plus presigned image URLs

For multimodal pipelines that want one big markdown blob and the page screenshots as separate downloadable images.

- [Python](#tab-panel-190)
- [TypeScript](#tab-panel-191)

```
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic_plus",
    version="latest",
    output_options={"images_to_save": ["screenshot"]},
    expand=["markdown_full", "images_content_metadata"],
)


# One big markdown blob for the LLM
print(result.markdown_full)


# Each page screenshot as a downloadable URL
for image in result.images_content_metadata.images:
    print(f"{image.filename}: {image.presigned_url}")
```

```
const result = await client.parsing.parse({
  file_id: file.id,
  tier: "agentic_plus",
  version: "latest",
  output_options: { images_to_save: ["screenshot"] },
  expand: ["markdown_full", "images_content_metadata"],
});


console.log(result.markdown_full);


for (const image of result.images_content_metadata?.images ?? []) {
  console.log(`${image.filename}: ${image.presigned_url}`);
}
```

## Retrieving results after the job runs

You don’t have to ask for everything you might ever need at parse time. You can run a parse job with one set of `expand` values and then call `client.parsing.get(job_id, expand=...)` later with a different set — without re-running the job.

This is the right pattern when:

- **You don’t know yet what you need.** Run with `expand=["markdown"]`, decide later you also want the items tree, fetch with `expand=["items"]` against the same job ID. Cheaper than re-parsing.
- **You’re working with large files.** Use `expand=["markdown_content_metadata"]` first to check `size_bytes` and decide whether to download.
- **You’re resuming work on a previously-parsed job.** Job results are persisted; pass the old `job_id` and an `expand` list to retrieve any field that was generated at parse time.

* [Python](#tab-panel-192)
* [TypeScript](#tab-panel-193)

```
from llama_cloud import LlamaCloud


client = LlamaCloud(api_key="llx-...")


# Step 1: parse with a minimal expand
result = client.parsing.parse(
    upload_file="doc.pdf",
    tier="cost_effective",
    version="latest",
    expand=["markdown_full"],
)
print(result.job.status)
print(result.markdown_full)


# Step 2: later, retrieve the text representation of the same job
text_result = client.parsing.get(
    job_id=result.job.id,
    expand=["text_full"],
)
print(text_result.text_full)
```

```
import fs from "fs";
import { LlamaCloud } from "@llamaindex/llama-cloud";


const client = new LlamaCloud({ apiKey: "llx-..." });


// Step 1: parse with a minimal expand
const result = await client.parsing.parse({
  upload_file: fs.createReadStream("doc.pdf"),
  tier: "cost_effective",
  version: "latest",
  expand: ["markdown_full"],
});
console.log(result.job.status);
console.log(result.markdown_full);


// Step 2: later, retrieve the text representation of the same job
const textResult = await client.parsing.get({
  job_id: result.job.id,
  expand: ["text_full"],
});
console.log(textResult.text_full);
```

## Content fields vs. metadata fields

Every `expand` value falls into one of two flavors. Knowing the difference saves you from accidentally downloading the same megabyte of markdown twice.

### Content fields (inline data)

Content fields return the **actual parsed data** in the API response. Use these when you need immediate access to the parsed content and the document is reasonably sized.

| Field           | Description                                                           | Best For                                            |
| --------------- | --------------------------------------------------------------------- | --------------------------------------------------- |
| `text`          | Plain text extraction from the document per page                      | Simple text analysis, search indexing               |
| `markdown`      | Markdown-formatted content with structure per page                    | Display, documentation, LLM prompts                 |
| `items`         | Structured JSON with typed elements (tables, headings, etc.) per page | Programmatic processing, data extraction            |
| `metadata`      | Page-level metadata (confidence scores, speaker notes, etc.)          | Quality assessment, presentation data               |
| `job_metadata`  | Job-level usage and processing details                                | Tracking credit usage, debugging job-level behavior |
| `markdown_full` | Full raw markdown file content (output.md)                            | Complete markdown output without pagination         |
| `text_full`     | Full plain text file content                                          | Complete text output without pagination             |

**Example response with content:**

```
{
  "job": {
    "id": "pjb-123",
    "status": "COMPLETED"
  },
  "text": {
    "pages": [
      {
        "page_number": 1,
        "text": "This is the extracted text from page 1..."
      }
    ]
  },
  "markdown": {
    "pages": [
      {
        "page_number": 1,
        "markdown": "# Heading\n\nThis is markdown content..."
      }
    ]
  }
}
```

### Metadata fields (presigned download URLs)

Metadata fields return **presigned download URLs** instead of the actual content. The result file is stored in S3 and you fetch it with a follow-up HTTP request. Use these when:

- The result is large and you want to defer the download
- You want to stream the file directly to your own storage
- You only need to know whether the file exists and how big it is, not its contents

| Field                            | Description                                | Download Format      |
| -------------------------------- | ------------------------------------------ | -------------------- |
| `text_content_metadata`          | Download URL for plain text file           | `.txt` file          |
| `markdown_content_metadata`      | Download URL for markdown file             | `.md` file           |
| `items_content_metadata`         | Download URL for structured JSON           | `.json` file         |
| `metadata_content_metadata`      | Download URL for metadata file             | `.json` file         |
| `xlsx_content_metadata`          | Download URL for spreadsheet export        | `.xlsx` file         |
| `output_pdf_content_metadata`    | Download URL for output PDF                | `.pdf` file          |
| `images_content_metadata`        | List of download URLs for extracted images | `.png`, `.jpg` files |
| `markdown_full_content_metadata` | Download URL for full raw markdown         | `.md` file           |
| `text_full_content_metadata`     | Download URL for full plain text           | `.txt` file          |

**Example response with metadata:**

```
{
  "job": {
    "id": "pjb-123",
    "status": "COMPLETED"
  },
  "result_content_metadata": {
    "md": {
      "size_bytes": 45678,
      "exists": true,
      "presigned_url": "https://s3.amazonaws.com/bucket/path/output.md?signature=..."
    },
    "fullText": {
      "size_bytes": 23456,
      "exists": true,
      "presigned_url": "https://s3.amazonaws.com/bucket/path/output.txt?signature=..."
    }
  }
}
```

### Images content metadata

The `images_content_metadata` field is special — it returns a structured list of all extracted images with individual download URLs:

```
{
  "job": { ... },
  "images_content_metadata": {
    "total_count": 3,
    "images": [
      {
        "index": 0,
        "filename": "image_0.png",
        "content_type": "image/png",
        "size_bytes": 12345,
        "presigned_url": "https://s3.amazonaws.com/..."
      },
      {
        "index": 1,
        "filename": "image_1.jpg",
        "content_type": "image/jpeg",
        "size_bytes": 23456,
        "presigned_url": "https://s3.amazonaws.com/..."
      }
    ]
  }
}
```

You can filter to specific images using the `image_filenames` parameter:

- [Python](#tab-panel-194)
- [TypeScript](#tab-panel-195)

```
result = client.parsing.get(
    job_id="job-123",
    expand=["images_content_metadata"],
    image_filenames=["image_0.png", "image_5.jpg"]
)
```

```
const result = await client.parsing.get({
  job_id: "job-123",
  expand: ["images_content_metadata"],
  image_filenames: ["image_0.png", "image_5.jpg"],
});
```

### Grounded items content metadata

When a parse job is created with [`output_options.granular_bboxes`](/llamaparse/parse/guides/configuring-parse/#granular-bounding-boxes/index.md) set, Parse writes a **grounded-items JSONL sidecar** with word / line / cell bounding boxes and source-text spans for every item. The presigned download URL is **automatically included** under `result_content_metadata.grounded_items` — you do **not** need to add anything to `expand`.

```
{
  "job": { "id": "pjb-123", "status": "COMPLETED" },
  "result_content_metadata": {
    "grounded_items": {
      "size_bytes": 123456,
      "exists": true,
      "presigned_url": "https://s3.amazonaws.com/bucket/path/grounded_items.jsonl?signature=..."
    }
  }
}
```

The sidecar is a **JSONL** file (one JSON object per line, not a JSON array) — one row per page. Each row is one of two shapes:

```
// Success row
{
  "page_number": 1,
  "page_width": 612,
  "page_height": 792,
  "success": true,
  "items": [
    {
      "type": "text",
      "md": "Hello world",
      "bbox": [{ "x": 72.0, "y": 100.0, "w": 200.0, "h": 12.0 }],
      "grounding": {
        "source": "md",
        "lines": [
          {
            "span": [0, 11],
            "bbox": { "x": 72.0, "y": 100.0, "w": 200.0, "h": 12.0 },
            "words": [
              { "span": [0, 5],  "bbox": { "x": 72.0, "y": 100.0, "w": 35.0, "h": 12.0 } },
              { "span": [6, 11], "bbox": { "x": 110.0, "y": 100.0, "w": 40.0, "h": 12.0 } }
            ]
          }
        ]
      }
    }
  ]
}


// Failure row — grounding could not be produced for this page
{ "page_number": 2, "success": false, "error": "..." }
```

Key shapes:

- `items[].bbox` — item-level layout boxes (same as the regular `items` expand).
- `items[].grounding.lines[]` — per-line bbox + `[start, end)` character span into the item’s markdown.
- `items[].grounding.lines[].words[]` — per-word bbox + character span (when requested).
- For table items, `grounding` is a `GroundedTableSupport` with `rows[row][col]` carrying per-cell bboxes and spans, plus `row_bboxes` / `column_bboxes`.
- `bbox.r` — optional rotation in degrees around the rect center, present when the underlying text is visually rotated; `x/y/w/h` describe the axis-aligned bounding rect of the unrotated content.

For a complete worked example — request, fetch, and walking the per-word/line/cell grounding — see the [Granular bounding boxes example](/llamaparse/parse/examples/parse_granular_bboxes/index.md).

## All available expand values (detailed reference)

### Content fields

#### text

Returns the plain text extraction from each page.

**Structure:**

```
{
  "text": {
    "pages": [
      {
        "page_number": 1,
        "text": "Extracted plain text content..."
      }
    ]
  }
}
```

#### markdown

Returns the markdown-formatted content from each page with preserved structure.

**Important:** Not available for the `fast` tier.

**Structure:**

```
{
  "markdown": {
    "pages": [
      {
        "page_number": 1,
        "success": true,
        "markdown": "# Heading\n\n## Subheading\n\nContent with **formatting**...",
        "header": "Page header",
        "footer": "LlamaIndex 2026"
      }
    ]
  }
}
```

#### items

Returns structured JSON with typed elements (tables, headings, lists, code blocks, etc.).

**Important:** Not available for the `fast` tier.

**Structure:**

```
{
  "items": {
    "pages": [
      {
        "page_number": 1,
        "page_width": 612.0,
        "page_height": 792.0,
        "items": [
          {
            "type": "heading",
            "level": 1,
            "value": "Document Title",
            "md": "# Document Title"
          },
          {
            "type": "table",
            "rows": [["Header1", "Header2"], ["Row1", "Data1"]],
            "html": "<table>...</table>",
            "csv": "Header1,Header2\nRow1,Data1",
            "md": "| Header1 | Header2 |\n|---------|---------|..."
          }
        ],
        "success": true
      }
    ]
  }
}
```

#### metadata

Returns page-level metadata including confidence scores, speaker notes, and document-specific information.

**Structure:**

```
{
  "metadata": {
    "pages": [
      {
        "page_number": 1,
        "confidence": 0.95,
        "speaker_notes": "Notes from presentation slide",
        "slide_section_name": "Introduction",
        "printed_page_number": "i",
        "original_orientation_angle": 0,
        "cost_optimized": false,
        "triggered_auto_mode": false
      }
    ],
    "document": {
      "XRBIData": "XBRL metadata for financial documents"
    }
  }
}
```

#### job\_metadata

Returns job-level metadata: usage and processing details for the parse job as a whole, separate from per-page metadata. Useful for tracking credit cost, job timing, and the configuration the job actually ran with.

#### markdown\_full

Returns the complete raw markdown output as a single string (the full output.md file).

**Structure:**

```
{
  "markdown_full": "# Complete Document\n\n## Chapter 1\n\nContent...\n\n---\n\n## Chapter 2..."
}
```

#### text\_full

Returns the complete raw plain text output as a single string (the full output.txt file).

### Metadata fields (download URLs)

All metadata fields return information about result files stored in S3, including presigned download URLs:

```
{
  "result_content_metadata": {
    "md": {
      "size_bytes": 45678,
      "exists": true,
      "presigned_url": "https://s3.amazonaws.com/..."
    },
    "fullText": {
      "size_bytes": 23456,
      "exists": true,
      "presigned_url": "https://s3.amazonaws.com/..."
    },
    "json": {
      "size_bytes": 67890,
      "exists": true,
      "presigned_url": "https://s3.amazonaws.com/..."
    }
  }
}
```

This includes:

- `text_content_metadata`
- `markdown_content_metadata`
- `items_content_metadata`
- `metadata_content_metadata`
- `xlsx_content_metadata`
- `output_pdf_content_metadata`
- `images_content_metadata` [See above](#images-content-metadata)
- `markdown_full_content_metadata`
- `text_full_content_metadata`
- `result_content_metadata.grounded_items` — auto-included when [`granular_bboxes`](/llamaparse/parse/guides/configuring-parse/#granular-bounding-boxes/index.md) is set; [see above](#grounded-items-content-metadata)

## Important limitations

### Fast tier and markdown

The `fast` tier does **not support markdown output**. Requesting `markdown`, `items`, `markdown_content_metadata`, or `items_content_metadata` with a fast-tier job returns a validation error:

```
{
  "detail": "Markdown expansion is not available for FAST tier jobs."
}
```

If you need any of those, use `cost_effective` or higher. See [Tiers](/llamaparse/parse/guides/tiers/#fast/index.md) for the full Fast-tier limitations.

### Presigned URL expiration

Presigned URLs expire after a limited time. Download files promptly after retrieving them, or call `client.parsing.get()` again with the same `expand` to get fresh URLs.

## See also

- [Tiers](/llamaparse/parse/guides/tiers/index.md) — `expand` values are gated by which tier you parsed with
- [Configuration Model](/llamaparse/parse/guides/configuring-parse/index.md) — `expand` is a top-level key, not nested in `output_options`
- [Output Options](/llamaparse/parse/guides/configuring-parse/#output-options/index.md) — what you can ask Parse to *generate* (which then becomes available via `expand`), including image assets, tables-as-spreadsheet, and printed page numbers
