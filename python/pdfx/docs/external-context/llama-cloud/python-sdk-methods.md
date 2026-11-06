---
source: Official LlamaParse docs
library: llama-cloud (LlamaParse Python SDK)
package: llama-cloud
topic: Python SDK method signatures and usage
fetched: 2026-06-12T00:00:00Z
official_docs: https://developers.llamaindex.ai/llamaparse/
---

# LlamaParse Python SDK - Method Signatures & Usage

## Installation

```bash
pip install llama-cloud>=2.1
```

## Client Initialization

```python
from llama_cloud import LlamaCloud, AsyncLlamaCloud

# Sync client
client = LlamaCloud()  # reads LLAMA_CLOUD_API_KEY from env

# Explicit API key
client = LlamaCloud(api_key="llx-...")

# Async client
client = AsyncLlamaCloud()
```

---

## 1. Upload a File: `client.files.create()`

### Signature

```python
client.files.create(
    file=...,       # Required: Path, bytes tuple, or file-like object
    purpose=...,    # Required: str - "parse", "extract", "classify", "split"
) -> FileObject
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | `Path \| str \| bytes \| tuple` | Yes | File to upload. Accepts: a `pathlib.Path`, a file path string, or a tuple `(filename, contents, media_type)` |
| `purpose` | `str` | Yes | Purpose of upload: `"parse"`, `"extract"`, `"classify"`, `"split"` |

### Response: `FileObject`

```python
{
    "id": "cafe1337-e0dd-4762-b5f5-769fef112558",  # Use this file_id for parsing
    # ... other file metadata
}
```

### Examples

```python
from pathlib import Path
from llama_cloud import LlamaCloud

client = LlamaCloud()

# Upload using a Path
file = client.files.create(
    file=Path("/path/to/document.pdf"),
    purpose="parse",
)

# Upload using bytes tuple
file = client.files.create(
    file=("document.txt", b"content", "text/plain"),
    purpose="parse",
)

# Upload using string path
file = client.files.create(
    file="./attention_is_all_you_need.pdf",
    purpose="parse",
)

# Access the file ID
print(file.id)  # "cafe1337-e0dd-4762-b5f5-769fef112558"
```

---

## 2. Parse a File: `client.parsing.parse()` (high-level) / `client.parsing.create()` (low-level)

### HIGH-LEVEL: `client.parsing.parse()` — Recommended

This is a **convenience method** that handles job polling automatically. It blocks until the job finishes and returns the full result.

```python
client.parsing.parse(
    file_id=...,          # Required: str - file ID from files.create()
    tier=...,             # Required: Literal["fast", "cost_effective", "agentic", "agentic_plus"]
    version=...,          # Required: Literal["latest", "2026-06-05", "2026-06-04", "2025-12-11"] | str
    expand=...,           # Optional: list[str] - what data to include in response
    # ... optional parameters below
) -> ParsingCreateResponse
```

### LOW-LEVEL: `client.parsing.create()` — For manual polling

```python
client.parsing.create(
    file_id=...,          # Optional: str (mutually exclusive with source_url)
    source_url=...,       # Optional: str (mutually exclusive with file_id)
    tier=...,             # Required
    version=...,          # Required
    # ... all optional parameters
) -> ParsingCreateResponse
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file_id` | `str` | No* | ID from `files.create()`. Mutually exclusive with `source_url` |
| `source_url` | `str` | No* | Publicly accessible URL. Mutually exclusive with `file_id` |
| `tier` | `Literal["fast", "cost_effective", "agentic", "agentic_plus"]` | Yes | Parsing tier |
| `version` | `str` | Yes | Version for tier: `"latest"` or pinned date |
| `expand` | `list[str]` | No | What to include in response (see expand values below) |
| `agentic_options` | `dict` | No | `{"custom_prompt": "..."}` for AI tiers |
| `crop_box` | `dict` | No | `{"top": 0, "bottom": 1, "left": 0, "right": 1}` (ratios 0-1) |
| `disable_cache` | `bool` | No | Force re-parsing |
| `input_options` | `dict` | No | Format-specific options (html, pdf, spreadsheet, presentation) |
| `output_options` | `dict` | No | Markdown, images, spatial text, table options |
| `processing_options` | `dict` | No | OCR languages, table extraction, chart parsing |
| `page_ranges` | `dict` | No | `{"max_pages": int, "target_pages": "1,3,5-8"}` (1-based!) |
| `processing_control` | `dict` | No | Timeouts, failure conditions |
| `client_name` | `str` | No | Identifier for analytics |
| `http_proxy` | `str` | No | Proxy for source_url fetching |

---

## 3. Check Job Status: `client.parsing.get()`

```python
client.parsing.get(
    job_id=...,           # Required: str - job ID from parsing.create()
    expand=...,           # Optional: list[str] - what data to include
) -> ParsingGetResponse
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `job_id` | `str` | Yes | The job ID from `parsing.create()` |
| `expand` | `list[str]` | No | What data to include (can differ from original parse call) |
| `image_filenames` | `list[str]` | No | Filter specific images when using `images_content_metadata` |

### Response Status

```python
result = client.parsing.get(job_id="job-123", expand=["markdown"])
print(result.job.status)  # "PENDING" | "RUNNING" | "COMPLETED" | "FAILED"
```

**Key insight**: You can call `client.parsing.get()` with different `expand` values than you used in the original parse call — without re-parsing the document. This is useful when:
- You initially parsed with `expand=["markdown"]` and later want `expand=["items"]`
- You want to check presigned URL freshness
- You're resuming work on a previously-parsed job

---

## 4. Async Usage

```python
from llama_cloud import AsyncLlamaCloud
import asyncio

async def main():
    client = AsyncLlamaCloud()
    
    # Upload
    file = await client.files.create(file="doc.pdf", purpose="parse")
    
    # Parse (high-level, handles polling)
    result = await client.parsing.parse(
        file_id=file.id,
        tier="agentic",
        version="latest",
        expand=["markdown"],
    )
    
    # Or low-level create + manual get
    job = await client.parsing.create(
        file_id=file.id,
        tier="agentic",
        version="latest",
    )
    # Later...
    result = await client.parsing.get(job_id=job.id, expand=["markdown"])

asyncio.run(main())
```

---

## Tier Reference

| Tier | Description | Markdown Support | Use Case |
|------|-------------|-----------------|----------|
| `fast` | Rule-based, cheapest, no AI | ❌ No | Plain text documents at high volume |
| `cost_effective` | Balanced speed and quality | ✅ Yes | Text-heavy documents with minimal visual structure |
| `agentic` | Full AI-powered parsing | ✅ Yes | Visually rich documents (default for most workloads) |
| `agentic_plus` | Premium AI, highest accuracy | ✅ Yes | Complex tables, dense charts, multi-column layouts |

## Version Pinning

Current `latest` by tier:
- `fast`: `2025-12-11`
- `cost_effective`: `2026-06-05`
- `agentic`: `2026-06-04`
- `agentic_plus`: `2026-06-04`

List all versions: `GET /api/v2/parse/versions`
