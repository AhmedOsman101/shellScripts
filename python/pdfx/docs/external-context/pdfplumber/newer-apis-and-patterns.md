---
source: Context7 API / GitHub README / CHANGELOG
library: pdfplumber
package: pdfplumber
topic: Newer APIs, version info, and recent improvements
fetched: 2026-06-11T00:00:00Z
official_docs: https://github.com/jsvine/pdfplumber/blob/stable/CHANGELOG.md
---

# Newer pdfplumber APIs & Patterns (0.9.x – 0.11.x)

## Current Latest Version

- **pdfplumber 0.11.9** (released 2026-01-05)
- Depends on `pdfminer.six==20260107`

## Version History (Recent)

| Version | Date | Key Changes |
|---------|------|-------------|
| 0.11.9 | 2026-01-05 | Upgraded pdfminer.six 20251107 → 20251230 |
| 0.11.x | 2025 | Multiple pdfminer.six version bumps, CTM/text direction improvements, edge_min_length_prefilter, line_dir_render/char_dir_render |

## Notable APIs & Features in Recent Versions

### 1. layout=True Direction Rendering (0.11.x?)

```python
# New line/char direction parameters for layout=True
page.extract_text(
    layout=True,
    line_dir_render="ttb",   # top-to-bottom (vertical text)
    char_dir_render="ltr",   # left-to-right within vertical lines
)
```

Valid values: `"ttb"` (top-to-bottom), `"btt"` (bottom-to-top), `"ltr"` (left-to-right), `"rtl"` (right-to-left).

### 2. x_tolerance_ratio (Dynamic Tolerance)

```python
# Instead of fixed x_tolerance, use ratio of character size
page.extract_text(x_tolerance_ratio=0.5)
# Dynamic tolerance = 0.5 * previous_char["size"]
```

Useful for mixed-font-size documents where spacing needs vary.

### 3. edge_min_length_prefilter Setting

```python
table_settings = {
    "edge_min_length_prefilter": 0.5,  # default: 1
    # Lower value catches very short dashed lines
}
```

### 4. PDFStructTree (Structure Tree Analysis)

```python
from pdfplumber.structuretree import PDFStructTree

with pdfplumber.open("file.pdf") as pdf:
    page = pdf.pages[0]
    stree = PDFStructTree(pdf, page)

    # find_all works like BeautifulSoup
    for el in stree.find_all("H1"):
        print(stree.element_bbox(el))

    # Support regex matching
    for el in stree.find_all(r"H[1-6]"):
        print(el["type"])
```

### 5. Page Manipulation Methods

```python
# Crop
page.crop(bbox, relative=False, strict=True)

# Filter objects by bounding box
page.within_bbox(bbox)     # objects fully inside
page.outside_bbox(bbox)    # objects fully outside

# Custom filter with callable
page.filter(lambda obj: obj.get("size", 0) > 12)

# Deduplicate overlapping characters
page.dedupe_chars(tolerance=1, extra_attrs=("fontname", "size"))

# Chain operations
result = page.crop(...).filter(...).dedupe_chars()
```

### 6. extract_words() Enhancements

```python
page.extract_words(
    extra_attrs=["fontname", "size"],  # added font info per word
    split_at_punctuation=True,         # smart punctuation splitting
    expand_ligatures=True,             # expand æ → ae, etc.
    return_chars=True,                 # include individual char objects
    use_text_flow=False,               # use PDF's text flow vs positional
)
```

### 7. Image & Annotation Access

```python
# Image metadata
for img in page.images:
    print(img["srcsize"], img["colorspace"], img["bits"])

# Annotations
for annot in page.annots:
    print(annot["contents"])

# Hyperlinks
for link in page.hyperlinks:
    print(link["uri"], link["x0"], link["top"])
```

## Recommended Modern Pattern for Text Extraction

```python
import pdfplumber

with pdfplumber.open("document.pdf") as pdf:
    for page in pdf.pages:
        # 1. Try table extraction first
        tables = page.find_tables()
        if tables:
            yield {"type": "table", "data": [t.extract() for t in tables]}

        # 2. Fall back to layout-preserving text
        text = page.extract_text(
            layout=True,
            x_tolerance=3,
            y_tolerance=3,
            x_density=7.25,
            y_density=13,
        )
        if text.strip():
            yield {"type": "text", "data": text}

        # 3. For structured PDFs, check structure tree
        if page.structure_tree:
            yield {"type": "structure", "data": page.structure_tree}
```

## Key Gotchas

- **`layout=True` is experimental** — results vary by PDF generator. Test on your documents.
- **Table extraction was redesigned in 0.5.0** — old blog posts/tutorials may reference the old API.
- **structure_tree is None** for non-tagged PDFs (most scanned or print-to-PDF documents).
- **`extract_text_simple()`** is faster but less accurate — no layout option.
