---
source: Context7 API / GitHub README / docs/structure.md
library: pdfplumber
package: pdfplumber
topic: Heading/text structure detection with structure_tree and PDFStructTree
fetched: 2026-06-11T00:00:00Z
official_docs: https://github.com/jsvine/pdfplumber/blob/stable/docs/structure.md
---

# Structure / Heading Detection in pdfplumber

## Built-in Logical Structure Tree

pdfplumber can access the **PDF's logical structure tree** (also called "Tagged PDF" structure) — if it exists in the document. This is **not** AI-powered; it reads native PDF structure metadata that some PDF producers embed.

### Key APIs

| Property | Returns | Description |
|----------|---------|-------------|
| `pdf.structure_tree` | `list[dict]` or `None` | Document-level logical structure tree |
| `page.structure_tree` | `list[dict]` or `None` | Page-level structure tree |
| `PDFStructTree(pdf, page)` | `PDFStructTree` instance | Advanced structure tree analysis with find/search |

### Page.structure_tree Element Format

```python
for element in page.structure_tree:
    print(element["type"])       # e.g., "H1", "P", "Table", "Figure", "TD", "TH"
    print(element["mcids"])      # list of marked content IDs linked to this element
    print(element.get("lang"))   # optional: language code
    print(element.get("alt_text"))  # optional: alternative text for accessibility
    print(element.get("actual_text"))  # optional: actual text content
    print(element.get("attributes"))   # optional: may include "BBox" bounding box
    for child in element.children:
        print(child["type"])
```

### PDFStructTree Class (Advanced)

```python
from pdfplumber.structuretree import PDFStructTree

with pdfplumber.open("file.pdf") as pdf:
    page = pdf.pages[0]
    stree = PDFStructTree(pdf, page)

    # Find all elements of a specific type (like BeautifulSoup)
    for h1 in stree.find_all("H1"):
        bbox = stree.element_bbox(h1)
        print(f"H1 bbox: {bbox}")

    # find_all accepts strings, regex patterns, or callable functions
    headings = stree.find_all(r"H[1-6]")  # all heading levels via regex
    table_cells = stree.find_all(lambda el: el["type"] in ("TD", "TH"))
```

## Important Limitation ⚠️

**This is NOT general-purpose heading/structure detection.** It only works for documents that have an embedded logical structure tree (Tagged PDFs). Many PDFs — especially scanned documents, PDFs from older tools, or PDFs generated from print-to-PDF workflows — **do not contain this metadata**.

For such documents, page.structure_tree will return `None` or an empty tree.

## Heuristic Alternatives (No Built-in)

pdfplumber does **not** have built-in heuristic heading detection (e.g., detecting headings by font size, boldness, or position). You must implement this yourself using the character-level data:

```python
# Heuristic: detect potential headings by font size
page = pdf.pages[0]
large_text_chars = [c for c in page.chars if c.get("size", 0) > 14]
heading_candidates = set(c["text"] for c in large_text_chars if not c["text"].isspace())

# Heuristic: detect bold headings
bold_chars = [c for c in page.chars if "Bold" in c.get("fontname", "")]
bold_text = "".join(c["text"] for c in bold_chars)

# Heuristic: group by font change + vertical whitespace
from itertools import groupby
chars = sorted(page.chars, key=lambda c: (c["doctop"], c["x0"]))
for fontname, group in groupby(chars, key=lambda c: c["fontname"]):
    group_chars = list(group)
    text = "".join(c["text"] for c in group_chars)
    if group_chars and group_chars[0]["size"] > 12:
        print(f"Heading candidate (size={group_chars[0]['size']}): {text}")
```
