---
source: Context7 API
library: PyMuPDF
package: pymupdf (import as fitz/pymupdf)
topic: Heading detection and structural analysis
fetched: 2026-06-11T00:00:00Z
official_docs: https://pymupdf.readthedocs.io/en/latest/pymupdf4llm/api.html
---

# Heading Detection & Structural Analysis

## Built-in Heading Detection: No (in core PyMuPDF)

**Core PyMuPDF does NOT have built-in heading detection** in the base library. However, there are two approaches:

---

## 1. PyMuPDF4LLM — `IdentifyHeaders` (Recommended)

The **pymupdf4llm** package (`pip install pymupdf4llm`) provides heading detection and markdown conversion.

### Automatic Heading Detection via `to_markdown()`

```python
import pymupdf4llm

# Auto-detects headings from font sizes
md_text = pymupdf4llm.to_markdown("doc.pdf")
```

### Manual `IdentifyHeaders` Object

```python
import pymupdf
import pymupdf4llm

doc = pymupdf.open("input.pdf")
my_headers = pymupdf4llm.IdentifyHeaders(doc, max_levels=3)
md_text = pymupdf4llm.to_markdown(doc, hdr_info=my_headers)
```

`IdentifyHeaders` scans the document to determine popular font sizes for body text vs headers and maps them to `#`, `##`, `###` levels.

### Custom Header Detection Function

You can provide a callable to define heading levels from span properties:

```python
def my_headers(span, page=None):
    if span["size"] > 20:
        return "# "
    if span["size"] > 16:
        return "## "
    return ""

md_text = pymupdf4llm.to_markdown("doc.pdf", hdr_info=my_headers)
```

### Using PDF Table of Contents (TOC)

```python
doc = pymupdf.open("input.pdf")
my_headers = pymupdf4llm.TocHeaders(doc)  # uses built-in TOC
md_text = pymupdf4llm.to_markdown(doc, hdr_info=my_headers)
```

This is faster than font-size scanning and leverages the document's existing structure.

### Disable Header Detection

```python
md_text = pymupdf4llm.to_markdown("doc.pdf", hdr_info=False)
```

---

## 2. Document.get_toc() — Built-in TOC Extraction

Core PyMuPDF can extract the document's Table of Contents:

```python
doc = pymupdf.open("doc.pdf")
toc = doc.get_toc()  # Returns list of [level, title, page]
# e.g., [[1, "Chapter 1", 1], [2, "Section 1.1", 2], ...]
```

---

## 3. Manual Structural Analysis via "dict" Output

For custom structural analysis, use page text as "dict" and analyze span properties:

```python
page = doc[0]
blocks = page.get_text("dict", sort=True)["blocks"]

for block in blocks:
    for line in block["lines"]:
        for span in line["spans"]:
            # span["size"] — font size
            # span["font"] — font name
            # span["flags"] — bold/italic/underline bits
            # span["color"] — text color
            # span["bbox"] — position
            print(f"Font '{span['font']}' size={span['size']}: {span['text']}")
```

You can use font size deltas, bold flags, and positioning to infer headings manually.

## Summary

| Method | Package | Heading Detection | Notes |
|--------|---------|-------------------|-------|
| `pymupdf4llm.to_markdown()` | pymupdf4llm | ✅ Automatic (font-size) | Best all-in-one |
| `IdentifyHeaders(doc)` | pymupdf4llm | ✅ Manual font-size mapping | Scan + reuse |
| `TocHeaders(doc)` | pymupdf4llm | ✅ Uses PDF TOC | Faster, no scan |
| `doc.get_toc()` | pymupdf (core) | ⚠️ Only if TOC exists | Just returns TOC |
| Manual span analysis | pymupdf (core) | ⚠️ DIY | Full control |
