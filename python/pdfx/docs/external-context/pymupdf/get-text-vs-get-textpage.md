---
source: Context7 API
library: PyMuPDF
package: pymupdf (import as fitz/pymupdf)
topic: page.get_text() vs page.get_textpage() — layout-preserving text extraction
fetched: 2026-06-11T00:00:00Z
official_docs: https://pymupdf.readthedocs.io/en/latest/page.html#Page.get_text
---

# get_text() vs get_textpage() — When to Use Which

## Quick Summary

| Feature | `page.get_text()` | `page.get_textpage()` |
|---------|-------------------|----------------------|
| Purpose | One-shot extraction in any format | Create reusable TextPage object |
| Speed (one call) | Fast | Slower (creates TextPage) |
| Speed (many formats) | N/A — each call re-extracts | ~50–95% faster on subsequent calls |
| Supports `clip` | ✅ Yes | ✅ Yes |
| Supports `flags` | ✅ Yes | ✅ Yes |
| Supports `sort` | ✅ Yes | ❌ No (sort on extract) |
| Supports OCR | ❌ (use textpage= kwarg) | ✅ `get_textpage_ocr()` variant |
| Return types | str, list, dict | TextPage object (call `.extractTEXT()` etc.) |

## page.get_text() — Full API

```python
get_text(option, *, clip=None, flags=None, textpage=None, sort=False, delimiters=None)
```

### Output Options (`option` parameter)

| Option | Method Delegate | Content | Return Type |
|--------|----------------|---------|-------------|
| `"text"` | `.extractTEXT()` | Text only | `str` |
| `"blocks"` | `.extractBLOCKS()` | Text + image metadata | `list` |
| `"words"` | `.extractWORDS()` | Text only | `list` |
| `"html"` | `.extractHTML()` | Text + images | `str` |
| `"xhtml"` | `.extractXHTML()` | Text + images | `str` |
| `"xml"` | `.extractXML()` | Text only | `str` |
| `"dict"` | `.extractDICT()` | Text + images | `dict` |
| `"json"` | `.extractJSON()` | Text + images | `str` |
| `"rawdict"` | `.extractRAWDICT()` | Text + images (raw) | `dict` |
| `"rawjson"` | `.extractRAWJSON()` | Text + images (raw) | `str` |

### Parameters

- **`clip`** (`rect_like`, default=None): Restrict extraction to this rectangle. Only content **fully inside** is returned. Use `pymupdf.INFINITE_RECT()` to avoid clipping. **No effect** on "html", "xhtml", "xml".
- **`flags`** (`int`, default=None): Bitwise flags to control text handling (see Flags section below).
- **`textpage`** (`TextPage`, default=None): Reuse an existing TextPage for **significant speedup** (50–95%, depending on option). If provided, `clip` and `flags` are **ignored** (they were set when creating the TextPage).
- **`sort`** (`bool`, default=False): Sort output by vertical then horizontal coordinates `(y1, x0)` for natural reading order. For "blocks"/"dict"/"json"/"rawdict"/"rawjson": sorts blocks. For "words"/"text": re-synthesizes text lines to follow visual reading sequence.
- **`delimiters`** (`str`, default=None): *Additional* word separators for "words" output only (new in v1.23.5). E.g., `delimiters="@."` splits "john.doe@outlook.com" into 4 words.

### Text Extraction Flags

These flags control what's included and how text is processed:

| Flag Constant | Description | Default |
|--------------|-------------|---------|
| `TEXT_PRESERVE_LIGATURES` | Keep ligature characters (ﬁ, ﬂ, etc.) | On |
| `TEXT_PRESERVE_WHITESPACE` | Preserve original whitespace | On |
| `TEXT_PRESERVE_IMAGES` | Include image metadata in output | Varies |
| `TEXT_DEHYPHENATE` | Remove hyphens at line breaks | Varies |
| `TEXT_PRESERVE_SPANS` | Preserve text span boundaries | Varies |

```python
# Example: include images
flags = pymupdf.TEXT_PRESERVE_LIGATURES | pymupdf.TEXT_PRESERVE_WHITESPACE | pymupdf.TEXT_PRESERVE_IMAGES
text = page.get_text("dict", flags=flags)

# Example: exclude images
flags = pymupdf.TEXT_PRESERVE_LIGATURES | pymupdf.TEXT_PRESERVE_WHITESPACE
```

## page.get_textpage() — Full API

```python
get_textpage(clip=None, flags=3)
```

Creates a reusable TextPage object. Default `flags=3` (TEXT_PRESERVE_LIGATURES | TEXT_PRESERVE_WHITESPACE).

### TextPage Methods

| Method | Description |
|--------|-------------|
| `.extractText(sort=False)` | Plain text as UTF-8 string |
| `.extractTEXT()` | Plain text (alias for extractText) |
| `.extractBLOCKS()` | Text blocks with positions |
| `.extractWORDS()` | Word list with positions |
| `.extractDICT()` | Full dictionary with structure |
| `.extractRAWDICT()` | Raw dictionary with low-level data |
| `.extractHTML()` | HTML-formatted output |
| `.extractXHTML()` | XHTML-formatted output |
| `.extractXML()` | XML-formatted output |

## Which is Better for Layout-Preserving Text Extraction?

**For layout preservation, `page.get_text()` with `sort=True` is generally preferred** because:

1. `sort=True` rearranges text in reading order (top-to-bottom, left-to-right), matching visual layout
2. You can combine `sort=True` with different output formats (`"dict"`, `"blocks"`, `"text"`) to get structured positional data
3. The `"dict"` or `"rawdict"` formats give you per-block, per-line, per-span positioning

**For performance when extracting multiple formats from the same page:**

```python
tp = page.get_textpage()  # create once (expensive)
text   = page.get_text("text",  textpage=tp)   # cheap
blocks = page.get_text("blocks", textpage=tp)  # cheap
data   = page.get_text("dict",  textpage=tp)   # cheap
```

This is **50–95% faster** than calling `page.get_text()` separately for each format.
