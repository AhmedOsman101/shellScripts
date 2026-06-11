---
source: Context7 API
library: PyMuPDF
package: pymupdf (import as fitz/pymupdf)
topic: OCR-scanned PDF handling
fetched: 2026-06-11T00:00:00Z
official_docs: https://pymupdf.readthedocs.io/en/latest/page.html#Page.get_textpage_ocr
---

# OCR-Scanned PDF Handling with PyMuPDF

## Recommended Approach

PyMuPDF uses **Tesseract-OCR** under the hood. You must have Tesseract installed with language data files.

## 1. Core Method: `page.get_textpage_ocr()`

```python
get_textpage_ocr(flags=3, language='eng', dpi=72, full=False, tessdata=None)
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `flags` | `int` | `3` | Text extraction flags (TEXT_PRESERVE_LIGATURES \| TEXT_PRESERVE_WHITESPACE) |
| `language` | `str` | `'eng'` | Tesseract language code(s). Use `+` for multiple: `'eng+deu'` |
| `dpi` | `int` | `72` | Resolution for OCR (higher = better quality, slower) |
| `full` | `bool` | `False` | If `True`, OCR the **entire** page. If `False`, only OCR areas without legible text |
| `tessdata` | `str` | `None` | Path to Tesseract's `tessdata` folder (auto-detected if omitted) |

### Important Notes

- **No `clip` parameter** — OCR always processes the full page
- When `full=True`, all recognized text gets font "GlyphLessFont"
- When `full=False` (partial), legible normal text keeps its properties and OCR text gets GlyphLessFont — but reading order may be affected (OCR text follows normal text)
- **Significantly slower** than regular text extraction

### Usage

```python
import pymupdf

doc = pymupdf.open("scanned.pdf")
page = doc[0]

# Full-page OCR
tp = page.get_textpage_ocr(language="eng", dpi=300, full=True)
text = page.get_text(textpage=tp)
print(text)

# Or use the TextPage directly
text = tp.extractText()
```

Check `pymupdf.get_tessdata()` to verify Tesseract is properly configured.

## 2. PyMuPDF4LLM Approach (Higher-Level)

The `pymupdf4llm` package wraps OCR into a simple API:

```python
import pymupdf4llm

# force_ocr=True performs full OCR on every page
md_text = pymupdf4llm.to_markdown(
    "scanned.pdf",
    force_ocr=False,       # If True, force OCR on all pages
    use_ocr=True,          # Enable OCR capability (default)
    ocr_language="eng",    # Tesseract language
    ocr_dpi=300,           # OCR resolution
    ocr_function=None,     # Custom OCR callable
)
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `force_ocr` | `False` | OCR every page even if text is extractable |
| `use_ocr` | `True` | Enable OCR capability |
| `ocr_language` | `'eng'` | Tesseract language code |
| `ocr_dpi` | `300` | OCR DPI (higher = better quality) |
| `ocr_function` | `None` | Custom OCR function for advanced use |

## 3. When Text Extraction Returns Garbled/Empty Text

If `page.get_text()` returns garbled characters or empty output:

1. **Cause**: Custom font encodings without proper CMAP, or scanned image-based PDFs
2. **Solution**: Use `page.get_textpage_ocr()` as fallback
3. **Alternative**: Use **OCRmyPDF** to add a hidden text layer before processing with PyMuPDF

## 4. Custom OCR Functions

You can inject a custom OCR function (e.g., using `pytesseract` or `easyocr`):

```python
def my_ocr(page, language="eng", dpi=300):
    # Custom OCR logic here
    # Return a TextPage or str
    ...

md_text = pymupdf4llm.to_markdown("doc.pdf", ocr_function=my_ocr)
```

## 5. Prerequisites

```bash
# Install Tesseract
sudo apt install tesseract-ocr tesseract-ocr-eng  # Debian/Ubuntu
brew install tesseract                             # macOS

# Install PyMuPDF + pymupdf4llm
pip install pymupdf pymupdf4llm
```
