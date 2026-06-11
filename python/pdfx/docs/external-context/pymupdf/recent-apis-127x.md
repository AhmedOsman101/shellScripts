---
source: Context7 API
library: PyMuPDF
package: pymupdf (import as fitz/pymupdf)
topic: Newer APIs in recent versions (1.23+ through 1.27.x)
fetched: 2026-06-11T00:00:00Z
official_docs: https://pymupdf.readthedocs.io/en/latest/changes.html
---

# Newer APIs in Recent PyMuPDF Versions

## Relevant Changes for Table/Text Extraction

### Version 1.23.0 (2023-08-22)
- **`Page.find_tables()` introduced** — Core table detection API
- Dropped Python 3.7 support

### Version 1.23.5
- **`delimiters` parameter added to `get_text()`** — Extra word separators for "words" output

### Version 1.24.0 (2024-03-21)
- **Table module improvements**:
  - Tables can be output as Markdown strings (`.to_markdown()`)
  - Better handling of `None` values in table headers
- Vector graphic redaction support
- Various table detection bug fixes and stability improvements

### Version 1.25.x
- Bug fixes and stability improvements for the table module
- (No major table/text API additions in this range)

### Version 1.27.x (Current)
- **Journaling support** for PDF updates — log, roll back, or replay changes to PDF documents
- Continued bug fixes for table detection edge cases

---

## PyMuPDF4LLM (Separate Package — Most Active Development)

This companion package (`pip install pymupdf4llm`) receives more frequent updates with extraction-focused features:

### pymupdf4llm v0.0.19+
- **`use_glyphs` parameter** — Use glyph numbers instead of characters for extraction (improved accuracy with unusual fonts)

### pymupdf4llm Features Overview

| Feature | Details |
|---------|---------|
| `to_markdown()` | Full PDF to Markdown conversion |
| `IdentifyHeaders` | Font-size-based heading detection |
| `TocHeaders` | TOC-based heading detection |
| Custom header functions | User-defined callable for heading logic |
| `page_chunks` | Per-page structured output with metadata |
| `force_ocr` / `use_ocr` | Tesseract OCR integration |
| `table_strategy` | Table detection strategy passthrough to `find_tables()` |
| `embed_images` | Embed images as base64 in markdown |

---

## Recommended Modern Workflow (2026)

For best results with table + text extraction:

```python
# Fast, simple approach
import pymupdf4llm

# Single call: tables detected, headings inferred, markdown output
md_text = pymupdf4llm.to_markdown(
    "document.pdf",
    page_chunks=True,              # Get per-page structured dicts
    table_strategy="lines_strict", # Better table precision
    show_progress=True,
)

for chunk in md_text:
    print(chunk["title"])          # Page number
    print(chunk["text"])           # Markdown content
```

For direct table access:
```python
import pymupdf

doc = pymupdf.open("document.pdf")
for page in doc:
    tables = page.find_tables(strategy="lines_strict")
    for t in tables:
        if t.row_count > 2:  # Filter small tables
            print(t.to_markdown())
```

## Migration Note

PyMuPDF removed the old `fitz` import alias in some newer distributions. **Always import as `pymupdf`** for forward compatibility:

```python
# Preferred (both work in current versions):
import pymupdf
# import fitz  # Legacy alias — may be deprecated
```
