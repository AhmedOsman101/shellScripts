---
source: Context7 API / GitHub README
library: pdfplumber
package: pdfplumber
topic: page.extract_text() API and layout option
fetched: 2026-06-11T00:00:00Z
official_docs: https://github.com/jsvine/pdfplumber
---

# page.extract_text() — Full API Reference

## Signature

```python
page.extract_text(
    x_tolerance=3,
    x_tolerance_ratio=None,
    y_tolerance=3,
    layout=False,
    x_density=7.25,
    y_density=13,
    line_dir_render=None,
    char_dir_render=None,
    **kwargs
)
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `x_tolerance` | int | `3` | Horizontal distance threshold for spacing. Adds spaces when `x1` of one char and `x0` of next exceeds this value. |
| `x_tolerance_ratio` | float or None | `None` | If set, uses dynamic `x_tolerance = ratio * previous_char["size"]` instead of fixed `x_tolerance`. |
| `y_tolerance` | int | `3` | Vertical distance threshold for newlines. Adds newlines when `doctop` diff between chars exceeds this. |
| `layout` | bool | `False` | **Experimental.** When `True`, attempts to mimic the visual structure of the page rather than linear text flow. |
| `x_density` | float | `7.25` | Characters per "point" (horizontal density for layout mode). |
| `y_density` | float | `13` | Lines per "point" (vertical density for layout mode). |
| `line_dir_render` | str or None | `None` | Line direction override: `"ttb"` (top-to-bottom), `"btt"`, `"ltr"`, `"rtl"`. |
| `char_dir_render` | str or None | `None` | Character direction override: `"ttb"`, `"btt"`, `"ltr"`, `"rtl"`. |
| `**kwargs` | — | — | Passed through to `.extract_words(...)` (used internally for layout mode). |

## layout=False (Default) — Linear Text Flow

- Spaces are inserted where horizontal gap > `x_tolerance`.
- Newlines are inserted where vertical gap > `y_tolerance`.
- Good for simple reading-order text extraction.
- **Not suitable for tabular data** — columns will be concatenated with spaces.

## layout=True — Visual Layout Preservation (Experimental ⚠️)

- Attempts to mimic the *structural layout* of the text on the page.
- Uses `x_density` (chars per point) and `y_density` (lines per point) to render character positions into a grid.
- **Good for:** Multi-column layouts, simple tables, forms, invoices.
- **Not a magic bullet:** Still experimental. Won't fix heavily complex or nested layouts.
- `**kwargs` like `keep_blank_chars`, `extra_attrs` are passed to `.extract_words()` internally.

### Recommendation for Tables

**For preserving table layout, `extract_text(layout=True)` is NOT the best approach.** Use one of these instead:

1. **`page.extract_tables()` or `page.find_tables()`** — dedicated table extraction with edge detection (preferred).
2. **`page.extract_text(keep_blank_chars=True)`** — preserves original whitespace, useful for monospaced/non-proportional layouts.
3. **`page.extract_text(layout=True, x_density=15, y_density=15)`** — can help with simpler columnar data but not reliable for real tables.

## Also Available: .extract_text_simple()

```python
page.extract_text_simple(x_tolerance=3, y_tolerance=3)
```

- Faster, simpler extraction — less sophisticated spacing logic than `extract_text()`.
- Good for quick extraction when you don't need precise positioning.
- No layout option.

## Also Available: .extract_text_lines()

```python
page.extract_text_lines(layout=False, strip=True, return_chars=True, **kwargs)
```

- **Experimental.** Returns a list of dicts representing lines of text.
- Each dict has keys: `text`, `top`, `bottom`, `x0`, `x1`, and optionally `chars`.
- `strip` works like `str.strip()` on the text (only relevant when `layout=True`).
- `return_chars=False` excludes individual character objects.
- `**kwargs` are passed to `.extract_text(layout=True, ...)`.

## .extract_words() — Lower-Level API

```python
page.extract_words(
    x_tolerance=3,
    y_tolerance=3,
    keep_blank_chars=False,
    use_text_flow=False,
    extra_attrs=["fontname", "size"],
    split_at_punctuation=True,
    expand_ligatures=True,
    return_chars=False
)
```

- Returns list of word dicts with: `text`, `x0`, `x1`, `top`, `bottom`, `fontname`, `size`.
- Good when you need per-word positioning data.
