---
source: Official LlamaParse docs
library: llama-cloud (LlamaParse Python SDK)
package: llama-cloud
topic: Complete working examples
fetched: 2026-06-12T00:00:00Z
official_docs: https://developers.llamaindex.ai/llamaparse/
---

# LlamaParse Python SDK - Complete Working Examples

## Basic: Upload + Parse + Get Markdown

```python
from llama_cloud import LlamaCloud

client = LlamaCloud()  # reads LLAMA_CLOUD_API_KEY from env

# Step 1: Upload the file
file = client.files.create(
    file="./attention_is_all_you_need.pdf",
    purpose="parse",
)

# Step 2: Parse (high-level, blocks until done)
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown"],
)

# Step 3: Access results
print(result.job.status)  # "COMPLETED"
for page in result.markdown.pages:
    print(f"Page {page.page_number}:")
    print(page.markdown)
```

## Get Full Document Markdown (single string)

```python
from llama_cloud import LlamaCloud

client = LlamaCloud()

file = client.files.create(file="document.pdf", purpose="parse")

result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown_full"],  # Full document as one string
)

# No page loop needed
print(result.markdown_full)
```

## Markdown + Structured Items

```python
from llama_cloud import LlamaCloud

client = LlamaCloud()

file = client.files.create(file="report.pdf", purpose="parse")

result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown", "items"],
)

# Per-page markdown for LLM
llm_input = "\n\n".join(p.markdown for p in result.markdown.pages)

# Walk items tree for tables
for page in result.items.pages:
    for item in page.items:
        if hasattr(item, "type") and item.type == "table":
            print(f"Table on page {page.page_number}: {len(item.rows)} rows")
            print(f"CSV: {item.csv}")
```

## With Custom Prompt

```python
from llama_cloud import LlamaCloud

client = LlamaCloud()

file = client.files.create(file="financial_report.pdf", purpose="parse")

result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",  # or "agentic_plus"
    version="latest",
    agentic_options={
        "custom_prompt": "Extract financial tables with currency symbols. Format dates as YYYY-MM-DD."
    },
    expand=["markdown"],
)
```

## With Page Ranges

```python
from llama_cloud import LlamaCloud

client = LlamaCloud()

file = client.files.create(file="large_document.pdf", purpose="parse")

result = client.parsing.parse(
    file_id=file.id,
    tier="cost_effective",
    version="latest",
    page_ranges={
        "max_pages": 10,           # Process max 10 pages
        "target_pages": "1,3,5-8", # Or specific pages (1-based!)
    },
    expand=["markdown"],
)
```

## With Images

```python
from llama_cloud import LlamaCloud

client = LlamaCloud()

file = client.files.create(file="presentation.pdf", purpose="parse")

result = client.parsing.parse(
    file_id=file.id,
    tier="agentic_plus",
    version="latest",
    output_options={
        "images_to_save": ["screenshot", "embedded"],
    },
    expand=["markdown_full", "images_content_metadata"],
)

# Full markdown
print(result.markdown_full)

# Download URLs for images
for image in result.images_content_metadata.images:
    print(f"{image.filename}: {image.presigned_url}")
```

## With Output Configuration

```python
from llama_cloud import LlamaCloud

client = LlamaCloud()

file = client.files.create(file="document.pdf", purpose="parse")

result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    output_options={
        "markdown": {
            "tables": {"output_tables_as_markdown": True},
            "annotate_links": True,
        },
        "images_to_save": ["screenshot"],
        "extract_printed_page_number": True,
    },
    processing_options={
        "ocr_parameters": {"languages": ["en", "fr"]},
    },
    expand=["text", "markdown", "items", "images_content_metadata"],
)
```

## Retrieve Results Later (Different expand)

```python
from llama_cloud import LlamaCloud

client = LlamaCloud(api_key="llx-...")

# Step 1: Parse with minimal expand
result = client.parsing.parse(
    file_id="file-id",
    tier="cost_effective",
    version="latest",
    expand=["markdown_full"],
)
print(result.job.status)
print(result.markdown_full)

# Step 2: Later, retrieve text of same job (no re-parse needed!)
text_result = client.parsing.get(
    job_id=result.job.id,
    expand=["text_full"],
)
print(text_result.text_full)
```

## Low-Level: Manual Polling (REST API style)

```python
from llama_cloud import LlamaCloud
import time

client = LlamaCloud()

# Upload
file = client.files.create(file="doc.pdf", purpose="parse")

# Create parse job (returns immediately)
job = client.parsing.create(
    file_id=file.id,
    tier="agentic",
    version="latest",
)
print(f"Job ID: {job.id}, Status: {job.status}")

# Poll for completion
while True:
    result = client.parsing.get(job_id=job.id, expand=["markdown"])
    print(f"Status: {result.job.status}")
    if result.job.status == "COMPLETED":
        break
    elif result.job.status == "FAILED":
        raise Exception(f"Job failed: {result.job}")
    time.sleep(2)

# Get results
for page in result.markdown.pages:
    print(page.markdown)
```

## Async Usage

```python
import asyncio
from llama_cloud import AsyncLlamaCloud

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
    
    for page in result.markdown.pages:
        print(page.markdown)

asyncio.run(main())
```

## Parse from URL

```python
from llama_cloud import LlamaCloud

client = LlamaCloud()

result = client.parsing.parse(
    source_url="https://example.com/document.pdf",  # instead of file_id
    tier="agentic",
    version="latest",
    expand=["markdown"],
)
```

## Error Handling

```python
import llama_cloud
from llama_cloud import LlamaCloud

client = LlamaCloud()

try:
    result = client.parsing.parse(
        file_id="file-id",
        tier="agentic",
        version="latest",
        expand=["markdown"],
    )
except llama_cloud.BadRequestError as e:
    print(f"Bad request: {e.status_code}")
except llama_cloud.AuthenticationError as e:
    print(f"Auth error: {e.status_code}")
except llama_cloud.RateLimitError as e:
    print(f"Rate limited: {e.status_code}")
except llama_cloud.APIError as e:
    print(f"API error: {e.status_code} - {e.__class__.__name__}")
```
