---
source: Context7 API
library: PyMuPDF
package: pymupdf (import as fitz/pymupdf)
topic: page.find_tables() — full API, options, and strategies
fetched: 2026-06-11T00:00:00Z
official_docs: https://pymupdf.readthedocs.io/en/latest/page.html#Page.find_tables
---

# Page.find_tables() — Full API Reference

## Method Signature

```python
find_tables(
    clip=None,
    strategy=None,
    vertical_strategy=None,
    horizontal_strategy=None,
    vertical_lines=None,
    horizontal_lines=None,
    snap_tolerance=None,
    snap_x_tolerance=None,
    snap_y_tolerance=None,
    join_tolerance=None,
    join_x_tolerance=None,
    join_y_tolerance=None,
    edge_min_length=3,
    min_words_vertical=3,
    min_words_horizontal=1,
    intersection_tolerance=None,
    intersection_x_tolerance=None,
    intersection_y_tolerance=None,
    text_tolerance=None,
    text_x_tolerance=None,
    text_y_tolerance=None,
    add_lines=None,
    add_boxes=None,
    paths=None
)
```

## Strategy Options

The `strategy` parameter (and the finer-grained `vertical_strategy` / `horizontal_strategy`) accepts:

| Strategy | Description |
|----------|-------------|
| `"lines"` | **(default)** Uses all vector graphics (lines, rectangles) on the page to detect table grid lines. |
| `"lines_strict"` | Like `"lines"` but ignores borderless rectangle vector graphics (e.g., background color fills that could cause false columns/lines). More precise for documents with colored backgrounds. |
| `"text"` | Uses text positions to generate "virtual" column/row boundaries. Useful for PDFs without visible grid lines (borderless tables). Controlled by `min_words_vertical` and `min_words_horizontal`. |

You can also set `vertical_strategy` and `horizontal_strategy` independently for fine-grained control.

## Key Filtering Parameters

**Note: There is NO built-in `min_rows` or `min_columns` parameter.** You filter after calling `find_tables()` by inspecting table attributes:

```python
tables = page.find_tables()
# Filter tables by row/column count:
filtered = [t for t in tables if t.row_count >= 3 and t.col_count >= 2]
```

### Table Object Attributes (for post-filtering)

| Attribute | Type | Description |
|-----------|------|-------------|
| `bbox` | `rect_like` | Bounding box of the table |
| `cells` | `list[rect_like]` | Bounding boxes of all cells |
| `col_count` | `int` | Number of columns |
| `row_count` | `int` | Number of rows |
| `rows` | `list[TableRow]` | Row objects (each with `bbox` and `cells`) |
| `header` | `TableHeader` | Header info (`names`, `bbox`, `cells`, `external`) |

### Table Output Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `extract()` | `list[list[str]]` | Table content as list of lists |
| `to_markdown()` | `str` | Markdown-formatted table |
| `to_pandas()` | `pandas.DataFrame` | Needs pandas + tabulate installed |

## Tolerance Parameters (all default to 3.0 unless noted)

| Parameter | Purpose |
|-----------|---------|
| `snap_tolerance` | Two horizontal/vertical lines within this distance are snapped into one |
| `snap_x_tolerance` / `snap_y_tolerance` | Per-dimension snap tolerance |
| `join_tolerance` | Line endpoints within this distance are joined |
| `join_x_tolerance` / `join_y_tolerance` | Per-dimension join tolerance |
| `edge_min_length` (default=3) | Lines shorter than this are ignored |
| `intersection_tolerance` | Orthogonal lines within this distance are considered intersecting |
| `intersection_x_tolerance` / `intersection_y_tolerance` | Per-dimension intersection tolerance |
| `text_tolerance` | Characters within this distance are combined into words |
| `text_x_tolerance` / `text_y_tolerance` | Per-dimension text tolerance |
| `min_words_vertical` (default=3) | Min words for "text" strategy vertical alignment |
| `min_words_horizontal` (default=1) | Min words for "text" strategy horizontal alignment |

## Helper Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `clip` | `rect_like` | Restrict search to this page region |
| `vertical_lines` | `sequence[float]` | Predefined y-coordinates for rows (disables row detection) |
| `horizontal_lines` | `sequence[float]` | Predefined x-coordinates for columns (disables col detection) |
| `add_lines` | `tuple/list` | Additional "virtual" lines to aid detection (does NOT disable auto-detection) |
| `add_boxes` | `tuple/list` | Additional "virtual" rectangles to aid detection |
| `paths` | `list` | Predefined vector graphics (skips internal extraction — faster) |

## Usage Example

```python
import pymupdf

doc = pymupdf.open("doc.pdf")
page = doc[0]

# Find tables with text strategy (for borderless tables)
tables = page.find_tables(
    strategy="text",
    clip=None,
    min_words_vertical=3,
    min_words_horizontal=1,
)

# Post-filter: only tables with >= 3 rows and >= 2 columns
for table in tables:
    if table.row_count >= 3 and table.col_count >= 2:
        print(table.to_markdown())
        # Or: df = table.to_pandas()
```
