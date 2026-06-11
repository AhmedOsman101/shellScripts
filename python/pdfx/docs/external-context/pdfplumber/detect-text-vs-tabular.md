---
source: Context7 API / GitHub README
library: pdfplumber
package: pdfplumber
topic: Detecting readable text vs. tabular data
fetched: 2026-06-11T00:00:00Z
official_docs: https://github.com/jsvine/pdfplumber
---

# Detecting Text Layout vs. Tabular Data

pdfplumber has **no built-in classifier** that determines "this is a readable layout" vs. "this is tabular data." You must build heuristics using the low-level object data.

## Recommended Approaches

### 1. Check for Lines / Rectangles (Strong Table Indicator)

If the page has many horizontal/vertical lines or filled rectangles, it likely has tabular content:

```python
page = pdf.pages[0]

# Lots of graphical lines = likely tabular
is_tabular = len(page.lines) > 10 or len(page.rects) > 5

# Specifically: check for grid-like line arrangements
h_lines = [l for l in page.lines if abs(l["y0"] - l["y1"]) < 1]  # horizontal
v_lines = [l for l in page.lines if abs(l["x0"] - l["x1"]) < 1]  # vertical
has_grid = len(h_lines) > 5 and len(v_lines) > 3
```

### 2. Check alignment/position variation (Word Distribution)

Columnar data has chars that align at common x-positions:

```python
import statistics
from collections import Counter

chars = page.chars
if chars:
    # Get x0 positions of first chars in each "line" (grouped by doctop)
    lines = {}
    for c in chars:
        key = round(c["doctop"], 0)
        if key not in lines:
            lines[key] = c["x0"]  # first char's x0

    x_starts = list(lines.values())
    # If chars consistently start at few x-positions = columnar/tabular
    start_positions = Counter(round(x, 0) for x in x_starts)
    if len(start_positions) < len(x_starts) * 0.5:  # many share same x starts
        is_columnar = True
```

### 3. Check for table detection success

The simplest check: try extracting tables and see if you get meaningful results:

```python
page = pdf.pages[0]
tables = page.find_tables()
if tables:
    # Check if detected tables cover significant page area
    covered_area = sum(
        (t.bbox[2] - t.bbox[0]) * (t.bbox[3] - t.bbox[1])
        for t in tables
    )
    page_area = page.width * page.height
    if covered_area / page_area > 0.3:
        is_tabular = True
```

### 4. Use extract_text(layout=True) and look for whitespace patterns

```python
text = page.extract_text(layout=True, x_density=15, y_density=15)
lines = text.split("\n")
# Tabular data often has multiple aligned whitespace gaps per line
multi_gap_lines = sum(1 for line in lines if line.count("  ") > 2)
if multi_gap_lines / len(lines) > 0.3:
    likely_tabular = True
```

### 5. Font analysis (monospaced = more likely tabular)

```python
fonts = set(c["fontname"] for c in page.chars if "fontname" in c)
mono_keywords = ["Courier", "Mono", "Fixed", "Console"]
is_mono = any(any(k in f for k in mono_keywords) for f in fonts)
# Monospaced fonts often used for tabular data
```

## Summary Decision Flow

```
Are there many lines/rectangles on the page?
  YES -> likely tabular -> use extract_tables()
  NO  -> try text-based table heuristics:
           Does text have consistent column-like x-start positions?
             YES -> try extract_tables(vertical_strategy="text")
             NO  -> extract text normally (layout=True for multi-column)
```

## Best Practice

Try table extraction first. If `find_tables()` returns nothing useful, fall back to `extract_text()`:

```python
def smart_extract(page):
    tables = page.find_tables()
    if tables:
        meaningful_tables = [
            t for t in tables
            if len(t.rows) >= 3 and len(t.columns) >= 2
        ]
        if meaningful_tables:
            return {"type": "table", "data": [t.extract() for t in meaningful_tables]}

    text = page.extract_text(layout=True)
    return {"type": "text", "data": text}
```
