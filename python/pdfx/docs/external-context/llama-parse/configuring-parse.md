---
title: Configuring Parse | Developer Documentation
description: Every option for a Parse job in one place — request anatomy, input controls, output formats, and processing features.
---

Parse has a lot of knobs. This page is the map: it shows how a parse request is structured and documents every option you can set.

For the full field-by-field reference, see the [Parse API Reference](https://developers.llamaindex.ai/reference/resources/parsing/methods/create). For controlling what comes *back* from a parse job, see [Retrieving Results](/llamaparse/parse/guides/retrieving-results/index.md).

## Request anatomy

Every Parse request is a JSON object. Only three fields are **required** — everything else is optional:

```
{
  // --- Required ---
  "file_id": "<file_id>",       // or "source_url" — exactly one is required
  "tier": "agentic",            // fast | cost_effective | agentic | agentic_plus
  "version": "latest",          // dated version string or "latest"


  // --- Optional ---
  "input_options": { /* file-type-specific hints */ },
  "processing_options": { /* how Parse processes the document */ },
  "agentic_options": { /* configures the agentic models */ },
  "output_options": { /* shape of what Parse returns */ },


  "crop_box": { /* page-level crop */ },
  "page_ranges": { /* parse specific pages only */ },
  "disable_cache": false,
  "processing_control": { /* timeouts and fail modes */ },
  "webhook_configurations": [ /* push results to a URL */ ]
}
```

The simplest valid request is just these three fields — everything below them can be added when you need it.

> **Note:** `expand` is not part of the parse request body. It’s a query parameter on the **GET result endpoint** that controls which fields come back. The SDKs handle this for you — when you pass `expand=["markdown"]` to `client.parsing.parse()`, the SDK submits the job, polls until complete, then retrieves the result with the right expand values. If you’re using the REST API directly, see [Retrieving Results](/llamaparse/parse/guides/retrieving-results/index.md).

### Where do I configure X?

| I want to…                            | Set this                                                                                                                             |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Parse only specific pages             | [`page_ranges.target_pages`](#page-ranges) (top-level)                                                                               |
| Strip headers/footers from every page | [`crop_box`](#crop-box) (top-level)                                                                                                  |
| Force a fresh parse (no cache)        | [`disable_cache: true`](#cache-control) (top-level)                                                                                  |
| Set a max job timeout                 | [`processing_control.timeouts.base_in_seconds`](#timeouts-and-failure-conditions) (top-level)                                        |
| Push results to a webhook             | [`webhook_configurations`](#webhook-configurations) (top-level)                                                                      |
| Set OCR language                      | [`processing_options.ocr_parameters.languages`](#ocr-languages)                                                                      |
| Skip watermark text                   | [`processing_options.ignore.ignore_diagonal_text`](#skipping-content-patterns)                                                       |
| Enable chart parsing                  | [`processing_options.specialized_chart_parsing`](#specialized-chart-parsing)                                                         |
| Auto-route pages by complexity        | [`processing_options.cost_optimizer.enable`](#cost-optimizer)                                                                        |
| Steer with a custom prompt            | [`agentic_options.custom_prompt`](#custom-prompt)                                                                                    |
| Get HTML tables instead of markdown   | [`output_options.markdown.tables.output_tables_as_markdown: false`](#markdown-output-options)                                        |
| Export tables as XLSX                 | [`output_options.tables_as_spreadsheet.enable`](#tables-as-spreadsheet)                                                              |
| Get per-page screenshots              | [`output_options.images_to_save: ["screenshot"]`](#image-assets)                                                                     |
| Preserve spatial layout               | [`output_options.spatial_text`](#spatial-text)                                                                                       |
| Get word / line / cell bounding boxes | [`output_options.granular_bboxes`](#granular-bounding-boxes)                                                                         |
| Control what comes back               | `expand` query param on the **GET** result endpoint — see [Retrieving Results](/llamaparse/parse/guides/retrieving-results/index.md) |

---

## Input options

**Control how Parse reads your document** — page ranges, crop boxes, file-type-specific controls, and cache behavior.

### Page ranges

Parse only the pages you need. Every page you skip is a page you don’t pay for.

**API key:** `page_ranges` — top-level.

- **`max_pages`** (integer) — cap total pages parsed, starting from page 1
- **`target_pages`** (string) — comma-separated 1-based pages and ranges, e.g. `"1,3,5-10"`

v1 migrators: indexing changed

v2 uses 1-based indexing. The first page is `1`, not `0`.

```
{ "page_ranges": { "max_pages": 5 } }
{ "page_ranges": { "target_pages": "1,3,7-12" } }
```

### Crop box

Strip repeating headers, footers, and margin chrome from every page. Four numbers (0.0–1.0), each the fraction to strip from that edge.

**API key:** `crop_box` — top-level.

```
{ "crop_box": { "top": 0.1, "bottom": 0.15 } }
```

This is a geometric crop, not a content filter. If the chrome moves between pages, use [content-based ignore rules](#skipping-content-patterns) instead.

### Cache control

Parse caches identical requests by default. Any change to parse options busts the cache automatically.

**API key:** `disable_cache` — top-level boolean.

```
{ "disable_cache": true }
```

Only disable for benchmarking, debugging, or verifying version pins.

### HTML pages

**API key:** `input_options.html`.

Parse walks the DOM, extracts visible content, and produces clean markdown. These controls strip noise that doesn’t belong in the output:

- **`make_all_elements_visible`** — force hidden CSS content visible. Useful when parts of the document are behind `display: none`, `visibility: hidden`, or JavaScript-driven UI states.
- **`remove_navigation_elements`** — strip menus, breadcrumbs, sidebar nav, and non-content chrome. Most useful when parsing a real web page rather than a hand-built HTML document.
- **`remove_fixed_elements`** — strip sticky headers, floating sidebars, and other fixed-position UI.

```
{
  "input_options": {
    "html": {
      "make_all_elements_visible": true,
      "remove_navigation_elements": true,
      "remove_fixed_elements": true
    }
  }
}
```

### Spreadsheets (XLSX, CSV)

**API key:** `input_options.spreadsheet`.

Parse handles spreadsheets where layouts aren’t clean rectangular tables — multiple logical tables stacked in one sheet, formulas with stale cached values, etc.

- **`detect_sub_tables_in_sheets`** — find and extract sub-tables within a single sheet. If your spreadsheet has three small tables stacked vertically with empty rows between them, Parse detects each as its own table instead of merging them.
- **`force_formula_computation_in_sheets`** — re-compute formula cells instead of using cached values. Enable when the file was edited but never recalculated, or you’re parsing a template with placeholder values. Can slow parsing on formula-heavy sheets.

```
{
  "input_options": {
    "spreadsheet": {
      "detect_sub_tables_in_sheets": true,
      "force_formula_computation_in_sheets": true
    }
  }
}
```

### Presentations (PPTX, Keynote)

**API key:** `input_options.presentation`.

Speaker notes are extracted by default — request `expand=["metadata"]` to retrieve them on per-slide metadata.

- **`out_of_bounds_content`** — extract content positioned beyond the visible slide boundaries. Presenters sometimes park notes, draft text, or reference images outside the visible area.
- **`skip_embedded_data`** — skip extraction of embedded chart data. Set to `true` if you only need slide text and the chart-data extraction is slowing you down.

```
{
  "input_options": {
    "presentation": {
      "out_of_bounds_content": true,
      "skip_embedded_data": false
    }
  }
}
```

### Images (camera photos)

**API key:** `input_options.image`.

Photos of documents — a receipt photographed on a desk, a form snapped with a phone — arrive tilted, surrounded by background, and unevenly lit. Parse can clean these up before parsing:

- **`camera_photo_correction`** — detect the document’s boundary in the photo, crop it, perspective-correct it, and flatten uneven lighting and shadows so the page parses like a flat scan. Applies to JPEG, PNG, WebP, and HEIC/HEIF inputs (the iPhone camera default). Detection is conservative: images that already look like clean scans or screenshots are left untouched, so it is safe to enable on mixed image batches.

```
{
  "input_options": {
    "image": {
      "camera_photo_correction": true
    }
  }
}
```

### PDFs

**API key:** `input_options.pdf` — see the [API reference](https://developers.llamaindex.ai/reference/resources/parsing/methods/create) for available PDF-specific options.

---

## Output options

**Shape what Parse returns.** Parse can emit several formats from the same job.

| I want…                                                          | Use                                                 |
| ---------------------------------------------------------------- | --------------------------------------------------- |
| Clean text for an LLM                                            | [Markdown](#markdown-output-options) (default)      |
| Whitespace-preserving layout                                     | [Spatial text](#spatial-text)                       |
| Tables as downloadable XLSX                                      | [Tables as spreadsheet](#tables-as-spreadsheet)     |
| Embedded images, screenshots, layout crops                       | [Image assets](#image-assets)                       |
| Printed page numbers for citations                               | [Printed page numbers](#printed-page-numbers)       |
| PDF copy of any parsed document                                  | [Exported PDF](#exported-pdf)                       |
| Word / line / cell bounding boxes for highlighting and grounding | [Granular bounding boxes](#granular-bounding-boxes) |
| Results pushed to my server                                      | [Webhooks](#webhook-configurations)                 |

### Markdown output options

**API key:** `output_options.markdown`.

| Symptom                                  | Knob                                       |
| ---------------------------------------- | ------------------------------------------ |
| Downstream needs HTML tables             | `output_tables_as_markdown: false`         |
| Table spans multiple pages               | `merge_continued_tables: true`             |
| Images transcribed instead of referenced | `inline_images: true`                      |
| Want link destinations in markdown       | `annotate_links: true`                     |
| Whitespace in table cells                | `compact_markdown_tables: true`            |
| Multi-line cell content                  | \`markdown\_table\_multiline\_separator: " |

```
{
  "output_options": {
    "markdown": {
      "annotate_links": true,
      "inline_images": true,
      "tables": { "merge_continued_tables": true, "output_tables_as_markdown": false }
    }
  }
}
```

### Spatial text

Preserves visual positioning using whitespace. Use for forms, CAD drawings, multi-column layouts, receipts.

**API key:** `output_options.spatial_text`. Retrieve via `expand=["text"]`.

Flags: `preserve_layout_alignment_across_pages`, `preserve_very_small_text`, `do_not_unroll_columns`.

### Tables as spreadsheet

Generates an XLSX file — one sheet per table.

**API key:** `output_options.tables_as_spreadsheet`. Retrieve via `expand=["xlsx_content_metadata"]`.

```
{ "output_options": { "tables_as_spreadsheet": { "enable": true } } }
```

### Image assets

**API key:** `output_options.images_to_save` — enum array: `"screenshot"`, `"embedded"`, `"layout"`. Retrieve via `expand=["images_content_metadata"]`.

```
{ "output_options": { "images_to_save": ["screenshot", "embedded"] } }
```

### Printed page numbers

**API key:** `output_options.extract_printed_page_number` (singular). Retrieve via `expand=["metadata"]`.

### Exported PDF

Always generated — no input config. Retrieve via `expand=["output_pdf_content_metadata"]`.

### Granular bounding boxes

Get per-**word**, per-**line**, and per-**table-cell** bounding boxes alongside the item-level layout boxes Parse already returns. Use this when you need to highlight individual words or lines on the source document (e.g., a PDF viewer that highlights the exact span a citation points to), or to ground extracted answers down to the glyph.

**API key:** `output_options.granular_bboxes` — array of one or more of `"word"`, `"line"`, `"cell"`. Empty list (default) disables granular boxes; only item-level layout boxes are returned.

```
{ "output_options": { "granular_bboxes": ["word", "line", "cell"] } }
```

When `granular_bboxes` is non-empty, Parse writes a **grounded-items JSONL sidecar** (one row per page) and includes a presigned download URL for it on the result. You don’t need to add anything to `expand` — see [grounded items in Retrieving Results](/llamaparse/parse/guides/retrieving-results/#grounded-items-content-metadata/index.md) for the response shape and the JSONL schema.

For a complete walk-through — request, sidecar fetch, and walking the per-word/line/cell grounding — see the [Granular bounding boxes example](/llamaparse/parse/examples/parse_granular_bboxes/index.md).

**Tier limits:** not available on `fast` (no item-level layout, so granular grounding has nothing to attach to).

### Webhook configurations

Push results instead of polling. For large PDFs, batch pipelines, or when the result goes to a different service.

**API key:** `webhook_configurations` — top-level array.

```
{
  "webhook_configurations": [{
    "webhook_url": "https://example.com/webhook",
    "webhook_events": ["parse.success"],
    "webhook_headers": { "Authorization": "Bearer your-token" }
  }]
}
```

**Security:** use HTTPS, put auth tokens in `webhook_headers` (not query params), verify the caller in your handler, never let untrusted users control `webhook_url`.

---

## Processing options

**Control how Parse processes your document** — flagship features, tuning knobs, and production controls.

### Cost Optimizer

**Pay premium prices only on pages that need it.** Routes each page to the right tier automatically: simple pages → `cost_effective`, complex pages → your selected tier. Both groups run in parallel.

**API key:** `processing_options.cost_optimizer`. Available on `agentic` and `agentic_plus` only.

```
{ "processing_options": { "cost_optimizer": { "enable": true } } }
```

**When to use:** mixed-complexity documents where most pages are prose. **When to skip:** every page is table-heavy, you’re already on `cost_effective`/`fast`, or you need exact reproducibility.

Request `expand=["metadata"]` to see which pages were cost-optimized (`cost_optimized: true/false` per page).

### Specialized Chart Parsing

Extract chart/graph data as structured tables — bar heights, line values, pie percentages.

**API key:** `processing_options.specialized_chart_parsing` — enum: `"efficient"`, `"agentic"`, `"agentic_plus"`. **Default-on for Agentic Plus.** Not available on `fast`.

```
{ "processing_options": { "specialized_chart_parsing": "agentic_plus" } }
```

Retrieve chart data via `expand=["items"]`. See the [chart parsing tutorial](/llamaparse/parse/examples/parse_charts_pandas/index.md).

### Custom Prompt

Steer the parser with natural-language instructions — focus on specific content, preserve formats, give document context.

**API key:** `agentic_options.custom_prompt` (not `processing_options`). Available on `cost_effective`, `agentic`, `agentic_plus`. **Not on `fast`.**

```
{ "agentic_options": { "custom_prompt": "This is a financial report. Preserve all currency symbols." } }
```

**Tips:** be specific, name the document type, say what to skip, specify output format, keep it short (2–3 sentences). For guaranteed structured extraction with a schema, use [LlamaExtract](/llamaparse/extract/getting_started/index.md) instead.

### Skipping content patterns

**API key:** `processing_options.ignore`.

| Flag                   | Skips                                   |
| ---------------------- | --------------------------------------- |
| `ignore_diagonal_text` | Watermarks (`CONFIDENTIAL`, `DRAFT`)    |
| `ignore_text_in_image` | Low-quality OCR text in embedded images |
| `ignore_hidden_text`   | White-on-white or CSS-hidden text       |

### OCR languages

**API key:** `processing_options.ocr_parameters.languages`. Only affects text from images — native text in born-digital PDFs is read directly.

```
{ "processing_options": { "ocr_parameters": { "languages": ["en", "fr", "de"] } } }
```

### Table extraction tuning

| Flag                          | What it does                                                        |
| ----------------------------- | ------------------------------------------------------------------- |
| `aggressive_table_extraction` | Try harder to find tables (may add false positives)                 |
| `disable_heuristics`          | Turn off outlined-table extraction and adaptive long-table handling |

### Timeouts and failure conditions

**API key:** `processing_control` — top-level (not under `processing_options`).

**Timeouts:** `base_in_seconds` + (`extra_time_per_page_in_seconds` × page count).

**Failure conditions:** `allowed_page_failure_ratio`, `fail_on_image_extraction_error`, `fail_on_image_ocr_error`, `fail_on_markdown_reconstruction_error`, `fail_on_buggy_font`.

```
{
  "processing_control": {
    "timeouts": { "base_in_seconds": 300, "extra_time_per_page_in_seconds": 30 },
    "job_failure_conditions": { "allowed_page_failure_ratio": 0.05 }
  }
}
```

---

## See also

- [Tiers](/llamaparse/parse/guides/tiers/index.md) — credit costs, tier comparison, version pinning
- [Retrieving Results](/llamaparse/parse/guides/retrieving-results/index.md) — the `expand` parameter and what comes back
- [Recipes](/llamaparse/parse/guides/recipes/index.md) — copy-pasteable snippets
- [API reference](https://developers.llamaindex.ai/reference/resources/parsing/methods/create) — full field-by-field listing
