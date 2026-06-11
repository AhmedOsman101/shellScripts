---
source: Context7 API / GitHub README
library: pdfplumber
package: pdfplumber
topic: extract_tables vs find_tables and table detection API
fetched: 2026-06-11T00:00:00Z
official_docs: https://github.com/jsvine/pdfplumber
---

# Table Extraction: extract_tables vs find_tables

## Overview

pdfplumber's table detection engine works by:
1. Identifying **edges** (from lines, rectangle borders, or text alignment)
2. Merging nearby edges via **snap** and **join** tolerances
3. Finding **intersections** of vertical/horizontal edges
4. Defining **cells** from the intersection grid
5. Grouping cells into **tables**

## Method Comparison

| Method | Returns | Use Case |
|--------|---------|----------|
| `.extract_tables(table_settings={})` | `list[list[list[str]]]` — table → row → cell | Quick access to all table data as arrays |
| `.extract_table(table_settings={})` | `list[list[str]]` — row → cell | Quick access to the **largest** table |
| `.find_tables(table_settings={})` | `list[Table]` — Table objects | Need metadata (bbox, cells, rows, columns) |
| `.find_table(table_settings={})` | `Table` or `None` | Get largest table as Table object |
| `.debug_tablefinder(table_settings={})` | `TableFinder` instance | Debugging why tables aren't detected |

### Key Difference

- **`extract_tables()`** is a **convenience method** — calls `find_tables()` internally, then calls `.extract()` on each Table object.
- **`find_tables()`** returns **Table objects** with methods:
  - `.extract()` — same as what extract_tables returns
  - `.cells` — list of cell bounding boxes
  - `.rows` — list of Row objects
  - `.columns` — list of Column objects
  - `.bbox` — bounding box of the table `(x0, top, x1, bottom)`

## Table Objects API

```python
with pdfplumber.open("file.pdf") as pdf:
    page = pdf.pages[0]
    tables = page.find_tables()
    for tbl in tables:
        print(tbl.bbox)           # (x0, top, x1, bottom)
        print(len(tbl.cells))     # number of cells
        print(len(tbl.rows))      # number of rows
        print(len(tbl.columns))   # number of columns
        data = tbl.extract()      # list of lists of strings
```

## Default Table Settings

```python
{
    "vertical_strategy": "lines",
    "horizontal_strategy": "lines",
    "explicit_vertical_lines": [],
    "explicit_horizontal_lines": [],
    "snap_tolerance": 3,
    "snap_x_tolerance": 3,
    "snap_y_tolerance": 3,
    "join_tolerance": 3,
    "join_x_tolerance": 3,
    "join_y_tolerance": 3,
    "edge_min_length": 3,
    "edge_min_length_prefilter": 1,
    "min_words_vertical": 3,
    "min_words_horizontal": 1,
    "intersection_tolerance": 3,
    "intersection_x_tolerance": 3,
    "intersection_y_tolerance": 3,
    "text_tolerance": 3,
    "text_x_tolerance": 3,
    "text_y_tolerance": 3,
}
```

## Vertical/Horizontal Strategies

| Strategy | Description |
|----------|-------------|
| `"lines"` | Use page's graphical lines AND rectangle edges. Default. |
| `"lines_strict"` | Use graphical lines ONLY — NOT rectangle edges. |
| `"text"` | Deduce imaginary lines from word alignment (left/right/center for vertical, tops for horizontal). |
| `"explicit"` | Only use lines you define in `explicit_vertical_lines` / `explicit_horizontal_lines`. |

## Strategy Selection Guide

- **Gridded tables with ruled lines:** Use default `"lines"` (works best).
- **Tables with partial or no borders:** Use `"text"` strategy — aligns words into columns.
- **Tables with only vertical or only horizontal rules:** Mix strategies, e.g. `vertical_strategy="lines"` + `horizontal_strategy="text"`.
- **Known column positions:** Use `"explicit"` with manually specified line coordinates.
- **Bordered cells that are rectangles:** Use `"lines_strict"` if rectangle borders confuse detection.

## Common Patterns for Difficult Tables

### Tables without visible lines (text-alignment based):
```python
table_settings = {
    "vertical_strategy": "text",
    "horizontal_strategy": "text",
    "min_words_vertical": 3,
    "min_words_horizontal": 1,
}
```

### Tables with explicit column boundaries:
```python
table_settings = {
    "vertical_strategy": "explicit",
    "horizontal_strategy": "text",
    "explicit_vertical_lines": [50, 150, 300, 450],
}
```

### Tables with very small/dashed lines:
```python
table_settings = {
    "edge_min_length": 1,
    "edge_min_length_prefilter": 0.5,
    "snap_tolerance": 5,
    "join_tolerance": 5,
}
```

## Debugging Table Detection

```python
finder = page.debug_tablefinder(table_settings)
print(f"Edges: {len(finder.edges)}")
print(f"Intersections: {len(finder.intersections)}")
print(f"Cells: {len(finder.cells)}")
print(f"Tables: {len(finder.tables)}")
```

## Cropping Before Table Extraction

Often helpful to crop before extracting:
```python
cropped = page.crop((x0, top, x1, bottom))
table = cropped.extract_table()
```
