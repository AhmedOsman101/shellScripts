## Parse File

**post** `/api/v2/parse`

Parse a file by file ID or URL.

Provide either `file_id` (a previously uploaded file) or
`source_url` (a publicly accessible URL). Configure parsing
with options like `tier`, `target_pages`, and `lang`.

## Tiers

- `fast` — rule-based, cheapest, no AI
- `cost_effective` — balanced speed and quality
- `agentic` — full AI-powered parsing
- `agentic_plus` — premium AI with specialized features

The job runs asynchronously. Poll `GET /parse/{job_id}` with
`expand=text` or `expand=markdown` to retrieve results.

### Query Parameters

- `organization_id: optional string`

- `project_id: optional string`

### Cookie Parameters

- `session: optional string`

### Body Parameters

- `tier: "fast" or "cost_effective" or "agentic" or "agentic_plus"`

  Parsing tier: 'fast' (rule-based, cheapest), 'cost_effective' (balanced), 'agentic' (AI-powered with custom prompts), or 'agentic_plus' (premium AI with highest accuracy)

  - `"fast"`

  - `"cost_effective"`

  - `"agentic"`

  - `"agentic_plus"`

- `version: "latest" or "2026-06-05" or "2026-06-04" or "2025-12-11" or string`

  Version for the selected tier. Use `latest`, or pin one of that tier's dated versions.

  Current `latest` by tier:

  - `fast`: `2025-12-11`
  - `cost_effective`: `2026-06-05`
  - `agentic`: `2026-06-04`
  - `agentic_plus`: `2026-06-04`

  Full list: `GET /api/v2/parse/versions`.

  - `"latest" or "2026-06-05" or "2026-06-04" or "2025-12-11"`

    Version for the selected tier. Use `latest`, or pin one of that tier's dated versions.

    Current `latest` by tier:

    - `fast`: `2025-12-11`
    - `cost_effective`: `2026-06-05`
    - `agentic`: `2026-06-04`
    - `agentic_plus`: `2026-06-04`

    Full list: `GET /api/v2/parse/versions`.

    - `"latest"`

    - `"2026-06-05"`

    - `"2026-06-04"`

    - `"2025-12-11"`

  - `string`

- `agentic_options: optional object { custom_prompt }`

  Options for AI-powered parsing tiers (cost_effective, agentic, agentic_plus).

  These options customize how the AI processes and interprets document content.
  Only applicable when using non-fast tiers.

  - `custom_prompt: optional string`

    Custom instructions for the AI parser. Use to guide extraction behavior, specify output formatting, or provide domain-specific context. Example: 'Extract financial tables with currency symbols. Format dates as YYYY-MM-DD.'

- `client_name: optional string`

  Identifier for the client/application making the request. Used for analytics and debugging. Example: 'my-app-v2'

- `crop_box: optional object { bottom, left, right, top }`

  Crop boundaries to process only a portion of each page. Values are ratios 0-1 from page edges

  - `bottom: optional number`

    Bottom boundary as ratio (0-1). 0=top edge, 1=bottom edge. Content below this line is excluded

  - `left: optional number`

    Left boundary as ratio (0-1). 0=left edge, 1=right edge. Content left of this line is excluded

  - `right: optional number`

    Right boundary as ratio (0-1). 0=left edge, 1=right edge. Content right of this line is excluded

  - `top: optional number`

    Top boundary as ratio (0-1). 0=top edge, 1=bottom edge. Content above this line is excluded

- `disable_cache: optional boolean`

  Bypass result caching and force re-parsing. Use when document content may have changed or you need fresh results

- `fast_options: optional unknown`

  Options for fast tier parsing (rule-based, no AI).

  Fast tier uses deterministic algorithms for text extraction without AI enhancement.
  It's the fastest and most cost-effective option, best suited for simple documents
  with standard layouts. Currently has no configurable options but reserved for
  future expansion.

- `file_id: optional string`

  ID of an existing file in the project to parse. Mutually exclusive with source_url

- `http_proxy: optional string`

  HTTP/HTTPS proxy for fetching source_url. Ignored if using file_id

- `input_options: optional object { html, pdf, presentation, spreadsheet }`

  Format-specific options (HTML, PDF, spreadsheet, presentation). Applied based on detected input file type

  - `html: optional object { make_all_elements_visible, remove_fixed_elements, remove_navigation_elements }`

    HTML/web page parsing options (applies to .html, .htm files)

    - `make_all_elements_visible: optional boolean`

      Force all HTML elements to be visible by overriding CSS display/visibility properties. Useful for parsing pages with hidden content or collapsed sections

    - `remove_fixed_elements: optional boolean`

      Remove fixed-position elements (headers, footers, floating buttons) that appear on every page render

    - `remove_navigation_elements: optional boolean`

      Remove navigation elements (nav bars, sidebars, menus) to focus on main content

  - `pdf: optional unknown`

    PDF-specific parsing options (applies to .pdf files)

  - `presentation: optional object { out_of_bounds_content, skip_embedded_data }`

    Presentation parsing options (applies to .pptx, .ppt, .odp, .key files)

    - `out_of_bounds_content: optional boolean`

      Extract content positioned outside the visible slide area. Some presentations have hidden notes or content that extends beyond slide boundaries

    - `skip_embedded_data: optional boolean`

      Skip extraction of embedded chart data tables. When true, only the visual representation of charts is captured, not the underlying data

  - `spreadsheet: optional object { detect_sub_tables_in_sheets, force_formula_computation_in_sheets, include_hidden_sheets }`

    Spreadsheet parsing options (applies to .xlsx, .xls, .csv, .ods files)

    - `detect_sub_tables_in_sheets: optional boolean`

      Detect and extract multiple tables within a single sheet. Useful when spreadsheets contain several data regions separated by blank rows/columns

    - `force_formula_computation_in_sheets: optional boolean`

      Compute formula results instead of extracting formula text. Use when you need calculated values rather than formula definitions

    - `include_hidden_sheets: optional boolean`

      Parse hidden sheets in addition to visible ones. By default, hidden sheets are skipped

- `output_options: optional object { additional_outputs, extract_printed_page_number, granular_bboxes, 4 more }`

  Output formatting options for markdown, text, and extracted images

  - `additional_outputs: optional array of string`

    Optional additional output artifacts to save alongside the primary parse output. Each value opts in to generating and persisting one extra file; the empty list (default) saves none. The three accepted values are: 'stripped_md' — per-page markdown stripped of formatting (links, bold/italic, images, HTML), saved as JSON for full-text-search indexing; fetch via `expand=stripped_markdown_content_metadata`. 'concatenated_stripped_txt' — all stripped pages concatenated into a single plain-text file with `\n\n---\n\n` between pages, useful for feeding the document into search or embedding pipelines as one blob; fetch via `expand=concatenated_stripped_markdown_content_metadata`. 'word_bbox' — raw word-level bounding boxes (one JSON object per word, with page number and x/y/w/h coordinates) saved as JSONL, useful for highlighting or grounding extracted answers back to the source document; fetch via `expand=raw_words_content_metadata`.

  - `extract_printed_page_number: optional boolean`

    Extract the printed page number as it appears in the document (e.g., 'Page 5 of 10', 'v', 'A-3'). Useful for referencing original page numbers

  - `granular_bboxes: optional array of "cell" or "line" or "word"`

    Bounding-box granularity levels to compute for the parse. 'word' computes one bounding box per detected word; 'line' computes one per text line; 'cell' computes one per table cell. Multiple levels can be requested. Empty list (default) disables granular bboxes — only item-level layout boxes are returned on the result. When set, the computed boxes are not inlined on the result items; they are written to a separate `grounded_items` sidecar (JSONL, one row per page) and exposed as `result_content_metadata.grounded_items` (a presigned download URL) on the parse result. Each row matches the `GroundedJsonItem` shape.

    - `"cell"`

    - `"line"`

    - `"word"`

  - `images_to_save: optional array of "screenshot" or "embedded" or "layout"`

    Image categories to extract and save. Options: 'screenshot' (full page renders useful for visual QA), 'embedded' (images found within the document), 'layout' (cropped regions from layout detection like figures and diagrams). Empty list saves no images

    - `"screenshot"`

    - `"embedded"`

    - `"layout"`

  - `markdown: optional object { annotate_links, inline_images, tables }`

    Markdown formatting options including table styles and link annotations

    - `annotate_links: optional boolean`

      Add link annotations to markdown output in the format [text](url). When false, only the link text is included

    - `inline_images: optional boolean`

      Embed images directly in markdown as base64 data URIs instead of extracting them as separate files. Useful for self-contained markdown output

    - `tables: optional object { compact_markdown_tables, markdown_table_multiline_separator, merge_continued_tables, output_tables_as_markdown }`

      Table formatting options including markdown vs HTML format and merging behavior

      - `compact_markdown_tables: optional boolean`

        Remove extra whitespace padding in markdown table cells for more compact output

      - `markdown_table_multiline_separator: optional string`

        Separator string for multiline cell content in markdown tables. Example: '<br>' to preserve line breaks, ' ' to join with spaces

      - `merge_continued_tables: optional boolean`

        Automatically merge tables that span multiple pages into a single table. The merged table appears on the first page with merged_from_pages metadata

      - `output_tables_as_markdown: optional boolean`

        Output tables as markdown pipe tables instead of HTML <table> tags. Markdown tables are simpler but cannot represent complex structures like merged cells

  - `spatial_text: optional object { do_not_unroll_columns, preserve_layout_alignment_across_pages, preserve_very_small_text }`

    Spatial text output options for preserving document layout structure

    - `do_not_unroll_columns: optional boolean`

      Keep multi-column layouts intact instead of linearizing columns into sequential text. Automatically enabled for non-fast tiers

    - `preserve_layout_alignment_across_pages: optional boolean`

      Maintain consistent text column alignment across page boundaries. Automatically enabled for document-level parsing modes

    - `preserve_very_small_text: optional boolean`

      Include text below the normal size threshold. Useful for footnotes, watermarks, or fine print that might otherwise be filtered out

  - `tables_as_spreadsheet: optional object { enable, guess_sheet_name }`

    Options for exporting tables as XLSX spreadsheets

    - `enable: optional boolean`

      Whether this option is enabled

    - `guess_sheet_name: optional boolean`

      Automatically generate descriptive sheet names from table context (headers, surrounding text) instead of using generic names like 'Table_1'

- `page_ranges: optional object { max_pages, target_pages }`

  Page selection: limit total pages or specify exact pages to process

  - `max_pages: optional number`

    Maximum number of pages to process. Pages are processed in order starting from page 1. If both max_pages and target_pages are set, target_pages takes precedence

  - `target_pages: optional string`

    Comma-separated list of specific pages to process using 1-based indexing. Supports individual pages and ranges. Examples: '1,3,5' (pages 1, 3, 5), '1-5' (pages 1 through 5 inclusive), '1,3,5-8,10' (pages 1, 3, 5-8, and 10). Pages are sorted and deduplicated automatically. Duplicate pages cause an error

- `processing_control: optional object { job_failure_conditions, timeouts }`

  Job execution controls including timeouts and failure thresholds

  - `job_failure_conditions: optional object { allowed_page_failure_ratio, fail_on_buggy_font, fail_on_image_extraction_error, 2 more }`

    Quality thresholds that determine when a job should fail vs complete with partial results

    - `allowed_page_failure_ratio: optional number`

      Maximum ratio of pages allowed to fail before the job fails (0-1). Example: 0.1 means job fails if more than 10% of pages fail. Default is 0.05 (5%)

    - `fail_on_buggy_font: optional boolean`

      Fail the job if a problematic font is detected that may cause incorrect text extraction. Buggy fonts can produce garbled or missing characters

    - `fail_on_image_extraction_error: optional boolean`

      Fail the entire job if any embedded image cannot be extracted. By default, image extraction errors are logged but don't fail the job

    - `fail_on_image_ocr_error: optional boolean`

      Fail the entire job if OCR fails on any image. By default, OCR errors result in empty text for that image

    - `fail_on_markdown_reconstruction_error: optional boolean`

      Fail the entire job if markdown cannot be reconstructed for any page. By default, failed pages use fallback text extraction

  - `timeouts: optional object { base_in_seconds, extra_time_per_page_in_seconds }`

    Timeout settings for job execution. Increase for large or complex documents

    - `base_in_seconds: optional number`

      Base timeout for the job in seconds (max 7200 = 2 hours). This is the minimum time allowed regardless of document size

    - `extra_time_per_page_in_seconds: optional number`

      Additional timeout per page in seconds (max 300 = 5 minutes). Total timeout = base + (this value × page count)

- `processing_options: optional object { aggressive_table_extraction, auto_mode_configuration, cost_optimizer, 4 more }`

  Document processing options including OCR, table extraction, and chart parsing

  - `aggressive_table_extraction: optional boolean`

    Use aggressive heuristics to detect table boundaries, even without visible borders. Useful for documents with borderless or complex tables

  - `auto_mode_configuration: optional array of object { parsing_conf, filename_match_glob, filename_match_glob_list, 33 more }`

    Conditional processing rules that apply different parsing options based on page content, document structure, or filename patterns. Each entry defines trigger conditions and the parsing configuration to apply when triggered

    - `parsing_conf: object { adaptive_long_table, aggressive_table_extraction, crop_box, 11 more }`

      Parsing configuration to apply when trigger conditions are met

      - `adaptive_long_table: optional boolean`

        Whether to use adaptive long table handling

      - `aggressive_table_extraction: optional boolean`

        Whether to use aggressive table extraction

      - `crop_box: optional object { bottom, left, right, top }`

        Crop box options for auto mode parsing configuration.

        - `bottom: optional number`

          Bottom boundary of crop box as ratio (0-1)

        - `left: optional number`

          Left boundary of crop box as ratio (0-1)

        - `right: optional number`

          Right boundary of crop box as ratio (0-1)

        - `top: optional number`

          Top boundary of crop box as ratio (0-1)

      - `custom_prompt: optional string`

        Custom AI instructions for matched pages. Overrides the base custom_prompt

      - `extract_layout: optional boolean`

        Whether to extract layout information

      - `high_res_ocr: optional boolean`

        Whether to use high resolution OCR

      - `ignore: optional object { ignore_diagonal_text, ignore_hidden_text }`

        Ignore options for auto mode parsing configuration.

        - `ignore_diagonal_text: optional boolean`

          Whether to ignore diagonal text in the document

        - `ignore_hidden_text: optional boolean`

          Whether to ignore hidden text in the document

      - `language: optional string`

        Primary language of the document

      - `outlined_table_extraction: optional boolean`

        Whether to use outlined table extraction

      - `presentation: optional object { out_of_bounds_content, skip_embedded_data }`

        Presentation-specific options for auto mode parsing configuration.

        - `out_of_bounds_content: optional boolean`

          Extract out of bounds content in presentation slides

        - `skip_embedded_data: optional boolean`

          Skip extraction of embedded data for charts in presentation slides

      - `spatial_text: optional object { do_not_unroll_columns, preserve_layout_alignment_across_pages, preserve_very_small_text }`

        Spatial text options for auto mode parsing configuration.

        - `do_not_unroll_columns: optional boolean`

          Keep column structure intact without unrolling

        - `preserve_layout_alignment_across_pages: optional boolean`

          Preserve text alignment across page boundaries

        - `preserve_very_small_text: optional boolean`

          Include very small text in spatial output

      - `specialized_chart_parsing: optional "agentic_plus" or "agentic" or "efficient"`

        Enable specialized chart parsing with the specified mode

        - `"agentic_plus"`

        - `"agentic"`

        - `"efficient"`

      - `tier: optional "fast" or "cost_effective" or "agentic" or "agentic_plus"`

        Override the parsing tier for matched pages. Must be paired with version

        - `"fast"`

        - `"cost_effective"`

        - `"agentic"`

        - `"agentic_plus"`

      - `version: optional "latest" or "2026-06-05" or "2026-06-04" or "2025-12-11" or string`

        Version for the override tier. Required when `tier` is set. Use `latest`, or pin one of that tier's dated versions.

        Current `latest` by tier:

        - `fast`: `2025-12-11`
        - `cost_effective`: `2026-06-05`
        - `agentic`: `2026-06-04`
        - `agentic_plus`: `2026-06-04`

        Full list: `GET /api/v2/parse/versions`.

        - `"latest" or "2026-06-05" or "2026-06-04" or "2025-12-11"`

          Version for the override tier. Required when `tier` is set. Use `latest`, or pin one of that tier's dated versions.

          Current `latest` by tier:

          - `fast`: `2025-12-11`
          - `cost_effective`: `2026-06-05`
          - `agentic`: `2026-06-04`
          - `agentic_plus`: `2026-06-04`

          Full list: `GET /api/v2/parse/versions`.

          - `"latest"`

          - `"2026-06-05"`

          - `"2026-06-04"`

          - `"2025-12-11"`

        - `string`

    - `filename_match_glob: optional string`

      Single glob pattern to match against filename

    - `filename_match_glob_list: optional array of string`

      List of glob patterns to match against filename

    - `filename_regexp: optional string`

      Regex pattern to match against filename

    - `filename_regexp_mode: optional string`

      Regex mode flags (e.g., 'i' for case-insensitive)

    - `full_page_image_in_page: optional boolean`

      Trigger if page contains a full-page image (scanned page detection)

    - `full_page_image_in_page_threshold: optional number or string`

      Threshold for full page image detection (0.0-1.0, default 0.8)

      - `number`

      - `string`

    - `image_in_page: optional boolean`

      Trigger if page contains non-screenshot images

    - `layout_element_in_page: optional string`

      Trigger if page contains this layout element type

    - `layout_element_in_page_confidence_threshold: optional number or string`

      Confidence threshold for layout element detection

      - `number`

      - `string`

    - `page_contains_at_least_n_charts: optional number or string`

      Trigger if page has more than N charts

      - `number`

      - `string`

    - `page_contains_at_least_n_images: optional number or string`

      Trigger if page has more than N images

      - `number`

      - `string`

    - `page_contains_at_least_n_layout_elements: optional number or string`

      Trigger if page has more than N layout elements

      - `number`

      - `string`

    - `page_contains_at_least_n_lines: optional number or string`

      Trigger if page has more than N lines

      - `number`

      - `string`

    - `page_contains_at_least_n_links: optional number or string`

      Trigger if page has more than N links

      - `number`

      - `string`

    - `page_contains_at_least_n_numbers: optional number or string`

      Trigger if page has more than N numeric words

      - `number`

      - `string`

    - `page_contains_at_least_n_percent_numbers: optional number or string`

      Trigger if page has more than N% numeric words

      - `number`

      - `string`

    - `page_contains_at_least_n_tables: optional number or string`

      Trigger if page has more than N tables

      - `number`

      - `string`

    - `page_contains_at_least_n_words: optional number or string`

      Trigger if page has more than N words

      - `number`

      - `string`

    - `page_contains_at_most_n_charts: optional number or string`

      Trigger if page has fewer than N charts

      - `number`

      - `string`

    - `page_contains_at_most_n_images: optional number or string`

      Trigger if page has fewer than N images

      - `number`

      - `string`

    - `page_contains_at_most_n_layout_elements: optional number or string`

      Trigger if page has fewer than N layout elements

      - `number`

      - `string`

    - `page_contains_at_most_n_lines: optional number or string`

      Trigger if page has fewer than N lines

      - `number`

      - `string`

    - `page_contains_at_most_n_links: optional number or string`

      Trigger if page has fewer than N links

      - `number`

      - `string`

    - `page_contains_at_most_n_numbers: optional number or string`

      Trigger if page has fewer than N numeric words

      - `number`

      - `string`

    - `page_contains_at_most_n_percent_numbers: optional number or string`

      Trigger if page has fewer than N% numeric words

      - `number`

      - `string`

    - `page_contains_at_most_n_tables: optional number or string`

      Trigger if page has fewer than N tables

      - `number`

      - `string`

    - `page_contains_at_most_n_words: optional number or string`

      Trigger if page has fewer than N words

      - `number`

      - `string`

    - `page_longer_than_n_chars: optional number or string`

      Trigger if page has more than N characters

      - `number`

      - `string`

    - `page_md_error: optional boolean`

      Trigger on pages with markdown extraction errors

    - `page_shorter_than_n_chars: optional number or string`

      Trigger if page has fewer than N characters

      - `number`

      - `string`

    - `regexp_in_page: optional string`

      Regex pattern to match in page content

    - `regexp_in_page_mode: optional string`

      Regex mode flags for regexp_in_page

    - `table_in_page: optional boolean`

      Trigger if page contains a table

    - `text_in_page: optional string`

      Trigger if page text/markdown contains this string

    - `trigger_mode: optional string`

      How to combine multiple trigger conditions: 'and' (all conditions must match, this is the default) or 'or' (any single condition can trigger)

  - `cost_optimizer: optional object { enable }`

    Cost optimizer configuration for reducing parsing costs on simpler pages.

    When enabled, the parser analyzes each page and routes simpler pages to faster,
    cheaper processing while preserving quality for complex pages. Only works with
    'agentic' or 'agentic_plus' tiers.

    - `enable: optional boolean`

      Enable cost-optimized parsing. Routes simpler pages to faster processing while complex pages use full AI analysis. May reduce speed on some documents. IMPORTANT: Only available with 'agentic' or 'agentic_plus' tiers

  - `disable_heuristics: optional boolean`

    Disable automatic heuristics including outlined table extraction and adaptive long table handling. Use when heuristics produce incorrect results

  - `ignore: optional object { ignore_diagonal_text, ignore_hidden_text, ignore_text_in_image }`

    Options for ignoring specific text types (diagonal, hidden, text in images)

    - `ignore_diagonal_text: optional boolean`

      Skip text rotated at an angle (not horizontal/vertical). Useful for ignoring watermarks or decorative angled text

    - `ignore_hidden_text: optional boolean`

      Skip text marked as hidden in the document structure. Some PDFs contain invisible text layers used for accessibility or search indexing

    - `ignore_text_in_image: optional boolean`

      Skip OCR text extraction from embedded images. Use when images contain irrelevant text (watermarks, logos) that shouldn't be in the output

  - `ocr_parameters: optional object { languages }`

    OCR configuration including language detection settings

    - `languages: optional array of ParsingLanguages`

      Languages to use for OCR text recognition. Specify multiple languages if document contains mixed-language content. Order matters - put primary language first. Example: ['en', 'es'] for English with Spanish

      - `"af"`

      - `"az"`

      - `"bs"`

      - `"cs"`

      - `"cy"`

      - `"da"`

      - `"de"`

      - `"en"`

      - `"es"`

      - `"et"`

      - `"fr"`

      - `"ga"`

      - `"hr"`

      - `"hu"`

      - `"id"`

      - `"is"`

      - `"it"`

      - `"ku"`

      - `"la"`

      - `"lt"`

      - `"lv"`

      - `"mi"`

      - `"ms"`

      - `"mt"`

      - `"nl"`

      - `"no"`

      - `"oc"`

      - `"pi"`

      - `"pl"`

      - `"pt"`

      - `"ro"`

      - `"rs_latin"`

      - `"sk"`

      - `"sl"`

      - `"sq"`

      - `"sv"`

      - `"sw"`

      - `"tl"`

      - `"tr"`

      - `"uz"`

      - `"vi"`

      - `"ar"`

      - `"fa"`

      - `"ug"`

      - `"ur"`

      - `"bn"`

      - `"as"`

      - `"mni"`

      - `"ru"`

      - `"rs_cyrillic"`

      - `"be"`

      - `"bg"`

      - `"uk"`

      - `"mn"`

      - `"abq"`

      - `"ady"`

      - `"kbd"`

      - `"ava"`

      - `"dar"`

      - `"inh"`

      - `"che"`

      - `"lbe"`

      - `"lez"`

      - `"tab"`

      - `"tjk"`

      - `"hi"`

      - `"mr"`

      - `"ne"`

      - `"bh"`

      - `"mai"`

      - `"ang"`

      - `"bho"`

      - `"mah"`

      - `"sck"`

      - `"new"`

      - `"gom"`

      - `"sa"`

      - `"bgc"`

      - `"th"`

      - `"ch_sim"`

      - `"ch_tra"`

      - `"ja"`

      - `"ko"`

      - `"ta"`

      - `"te"`

      - `"kn"`

  - `specialized_chart_parsing: optional "agentic_plus" or "agentic" or "efficient"`

    Enable AI-powered chart analysis. Modes: 'efficient' (fast, lower cost), 'agentic' (balanced), 'agentic_plus' (highest accuracy). Automatically enables extract_layout and precise_bounding_box when set

    - `"agentic_plus"`

    - `"agentic"`

    - `"efficient"`

- `source_url: optional string`

  Public URL of the document to parse. Mutually exclusive with file_id

- `webhook_configurations: optional array of object { webhook_events, webhook_headers, webhook_output_format, webhook_url }`

  Webhook endpoints for job status notifications. Multiple webhooks can be configured for different events or services

  - `webhook_events: optional array of string`

    Events that trigger this webhook. Options: 'parse.success' (job completed), 'parse.error' (job failed), 'parse.partial_success' (some pages failed), 'parse.pending', 'parse.running', 'parse.cancelled'. If not specified, webhook fires for all events

  - `webhook_headers: optional map[unknown]`

    Custom HTTP headers to include in webhook requests. Use for authentication tokens or custom routing. Example: {'Authorization': 'Bearer xyz'}

  - `webhook_output_format: optional "string" or "json"`

    Format of the webhook payload body. 'string' (default) sends the payload as a JSON-encoded string; 'json' sends it as a JSON object.

    - `"string"`

    - `"json"`

  - `webhook_url: optional string`

    HTTPS URL to receive webhook POST requests. Must be publicly accessible

### Returns

- `id: string`

  Unique parse job identifier

- `project_id: string`

  Project this job belongs to

- `status: "PENDING" or "RUNNING" or "COMPLETED" or 2 more`

  Current job status: PENDING, RUNNING, COMPLETED, FAILED, or CANCELLED

  - `"PENDING"`

  - `"RUNNING"`

  - `"COMPLETED"`

  - `"FAILED"`

  - `"CANCELLED"`

- `created_at: optional string`

  Creation datetime

- `error_message: optional string`

  Error details when status is FAILED

- `name: optional string`

  Optional display name for this parse job

- `tier: optional string`

  Parsing tier used for this job

- `updated_at: optional string`

  Update datetime

### Example

```http
curl https://api.cloud.llamaindex.ai/api/v2/parse \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $LLAMA_CLOUD_API_KEY" \
    -d '{
          "tier": "fast",
          "version": "latest"
        }'
```

#### Response

```json
{
  "id": "pjb-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "project_id": "prj-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "status": "PENDING",
  "created_at": "2019-12-27T18:11:19.117Z",
  "error_message": "error_message",
  "name": "Q4 Financial Report",
  "tier": "fast",
  "updated_at": "2019-12-27T18:11:19.117Z"
}
```
