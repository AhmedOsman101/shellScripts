---
source: Official LlamaParse docs
library: llama-cloud (LlamaParse Python SDK)
package: llama-cloud
topic: expand values and response object structures
fetched: 2026-06-12T00:00:00Z
official_docs: https://developers.llamaindex.ai/llamaparse/parse/guides/retrieving-results/
---

# LlamaParse - Expand Values & Response Object Structures

## How `expand` Works

By default, the API returns **only job metadata** (status, ID, error messages) — no parsed content. You add `expand` values to opt in to the data you want.

```python
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown"],  # ← This controls what comes back
)
```

---

## Inline Content expand Values

These return parsed data **directly in the response body**:

| expand Value | Response Field | Description | Tier Limits |
|-------------|---------------|-------------|-------------|
| `"markdown"` | `result.markdown` | Markdown per page | Not on `fast` |
| `"markdown_full"` | `result.markdown_full` | Full markdown as single string | Not on `fast` |
| `"text"` | `result.text` | Plain text per page | All tiers |
| `"text_full"` | `result.text_full` | Full plain text as single string | All tiers |
| `"items"` | `result.items` | Structured items tree per page | Not on `fast` |
| `"metadata"` | `result.metadata` | Per-page metadata | All tiers |
| `"job_metadata"` | `result.job_metadata` | Job-level processing details | All tiers |

## Download URL expand Values

These return **presigned S3 download URLs** instead of content:

| expand Value | Response Field | Description |
|-------------|---------------|-------------|
| `"markdown_content_metadata"` | `result.markdown_content_metadata` | Download URL for `.md` |
| `"markdown_full_content_metadata"` | `result.markdown_full_content_metadata` | Download URL for full `.md` |
| `"text_content_metadata"` | `result.text_content_metadata` | Download URL for `.txt` |
| `"text_full_content_metadata"` | `result.text_full_content_metadata` | Download URL for full `.txt` |
| `"items_content_metadata"` | `result.items_content_metadata` | Download URL for items `.json` |
| `"metadata_content_metadata"` | `result.metadata_content_metadata` | Download URL for metadata `.json` |
| `"images_content_metadata"` | `result.images_content_metadata` | List of images with download URLs |
| `"xlsx_content_metadata"` | `result.xlsx_content_metadata` | Download URL for `.xlsx` |
| `"output_pdf_content_metadata"` | `result.output_pdf_content_metadata` | Download URL for output PDF |

---

## Response Object Structures

### With `expand=["markdown"]`

```python
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown"],
)

# Access per-page markdown
for page in result.markdown.pages:
    print(f"Page {page.page_number}:")
    print(page.markdown)  # "# Heading\n\nContent..."
    # page.success: bool
    # page.header: str (optional)
    # page.footer: str (optional)
```

**Structure:**
```json
{
  "job": {
    "id": "pjb-123",
    "status": "COMPLETED"
  },
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

### With `expand=["markdown_full"]`

```python
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown_full"],
)

# One big markdown blob — no page loop needed
print(result.markdown_full)
# "# Complete Document\n\n## Chapter 1\n\nContent..."
```

**Structure:**
```json
{
  "job": { "id": "pjb-123", "status": "COMPLETED" },
  "markdown_full": "# Complete Document\n\n## Chapter 1\n\nContent...\n\n---\n\n## Chapter 2..."
}
```

### With `expand=["text"]`

```python
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["text"],
)

for page in result.text.pages:
    print(f"Page {page.page_number}: {page.text}")
```

**Structure:**
```json
{
  "job": { "id": "pjb-123", "status": "COMPLETED" },
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

### With `expand=["items"]`

```python
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["items"],
)

for page in result.items.pages:
    for item in page.items:
        if hasattr(item, "type"):
            if item.type == "table":
                print(f"Table: {item.csv}")
                print(f"Table rows: {item.rows}")
                print(f"Table HTML: {item.html}")
                print(f"Table MD: {item.md}")
            elif item.type == "heading":
                print(f"Heading (level {item.level}): {item.value}")
            elif item.type == "text":
                print(f"Text: {item.value}")
            elif item.type == "image":
                print(f"Image: {item.url}, caption: {item.caption}")
            elif item.type == "link":
                print(f"Link: {item.text} -> {item.url}")
            elif item.type == "code":
                print(f"Code ({item.language}): {item.value}")
            elif item.type == "list":
                print(f"List (ordered={item.ordered}): {item.md}")
```

**Structure:**
```json
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

### With `expand=["metadata"]`

```python
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["metadata"],
)

for page in result.metadata.pages:
    print(f"Page {page.page_number}:")
    print(f"  confidence: {page.confidence}")
    print(f"  cost_optimized: {page.cost_optimized}")
    print(f"  speaker_notes: {page.speaker_notes}")
```

**Structure:**
```json
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

### With `expand=["images_content_metadata"]`

```python
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic_plus",
    version="latest",
    output_options={"images_to_save": ["screenshot"]},
    expand=["images_content_metadata"],
)

for image in result.images_content_metadata.images:
    print(f"{image.filename}: {image.presigned_url}")
    print(f"  size: {image.size_bytes} bytes")
    print(f"  type: {image.content_type}")
```

**Structure:**
```json
{
  "images_content_metadata": {
    "total_count": 3,
    "images": [
      {
        "index": 0,
        "filename": "image_0.png",
        "content_type": "image/png",
        "size_bytes": 12345,
        "presigned_url": "https://s3.amazonaws.com/..."
      }
    ]
  }
}
```

### Combined expand values

```python
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown", "items", "metadata"],
)

# Access all three
for page in result.markdown.pages:
    print(page.markdown)

for page in result.items.pages:
    for item in page.items:
        if hasattr(item, "type") and item.type == "table":
            print(item.csv)

for page in result.metadata.pages:
    print(page.confidence)
```

---

## Job Status Response

```python
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown"],
)

# Job metadata always available
print(result.job.id)       # "pjb-123"
print(result.job.status)   # "COMPLETED" | "PENDING" | "RUNNING" | "FAILED"
```

**Job status values:**
- `"PENDING"` — Job queued, not yet started
- `"RUNNING"` — Job actively processing
- `"COMPLETED"` — Job finished successfully
- `"FAILED"` — Job encountered an error

---

## Presigned URL Expiration

Presigned URLs expire after a limited time. Download files promptly, or call `client.parsing.get()` again with the same `expand` to get fresh URLs.
