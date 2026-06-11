---
source: Official LlamaParse docs
library: llama-cloud (LlamaParse Python SDK)
package: llama-cloud
topic: v1 to v2 migration guide
fetched: 2026-06-12T00:00:00Z
official_docs: https://developers.llamaindex.ai/llamaparse/parse/guides/migration-v1-to-v2/
---

# LlamaParse v1 to v2 Migration Guide

## Key Changes Summary

v2 replaced v1's flat 70+ form parameters with structured JSON. The biggest changes:
- **`tier` and `version` are now required**
- Most parameters moved into nested option buckets
- Page indexing is now **1-based** (was 0-based)

## Quick Checklist

- Replace `POST /api/v1/parsing/upload` → `POST /api/v2/parse`
- Replace `parse_mode` → `tier` (`fast`, `cost_effective`, `agentic`, `agentic_plus`)
- Move `parsing_instruction` / `system_prompt` → `agentic_options.custom_prompt`
- Move `language` → `processing_options.ocr_parameters.languages`
- Replace `invalidate_cache` + `do_not_cache` → single `disable_cache` boolean
- Replace `webhook_url` (string) → `webhook_configurations` (array)
- Update `target_pages` from 0-based → **1-based indexing**
- Replace `bounding_box` → `crop_box`
- Remove `model` (auto-selected by tier), `gpt4o_mode`, `premium_mode`, `fast_mode`
- `high_res_ocr` and `precise_bounding_box` are always on in v2

## Parameter Mapping

### Basic options

| v1 | v2 | Notes |
|----|-----|-------|
| `input_url` | `source_url` | Renamed |
| `max_pages` | `page_ranges.max_pages` | Same |
| `target_pages` | `page_ranges.target_pages` | **1-based indexing** |
| `invalidate_cache` / `do_not_cache` | `disable_cache` | Combined |
| `language` | `processing_options.ocr_parameters.languages` | Same |

### Tier and model

| v1 | v2 | Notes |
|----|-----|-------|
| `parse_mode` | `tier` | Tier-based system |
| `model` | Auto-selected | Based on tier |
| `parsing_instruction` | `agentic_options.custom_prompt` | `cost_effective`/`agentic`/`agentic_plus` only |
| `formatting_instruction` / `system_prompt` / `user_prompt` | `agentic_options.custom_prompt` | Consolidated |

### Crop box

| v1 | v2 |
|----|-----|
| `bbox_top/bottom/left/right` | `crop_box.top/bottom/left/right` |

### Output options

| v1 | v2 |
|----|-----|
| `annotate_links` | `output_options.markdown.annotate_links` |
| `compact_markdown_table` | `output_options.markdown.tables.compact_markdown_tables` |
| `output_tables_as_HTML` | `output_options.markdown.tables.output_tables_as_markdown` (inverted) |
| `merge_tables_across_pages_in_markdown` | `output_options.markdown.tables.merge_continued_tables` |
| `save_images` / `take_screenshot` | `output_options.images_to_save` (array: `"screenshot"`, `"embedded"`, `"layout"`) |
| `extract_printed_page_number` | `output_options.extract_printed_page_number` |

### Processing options

| v1 | v2 |
|----|-----|
| `aggressive_table_extraction` | `processing_options.aggressive_table_extraction` |
| `specialized_chart_parsing_*` | `processing_options.specialized_chart_parsing: "efficient"/"agentic"/"agentic_plus"` |
| `skip_diagonal_text` | `processing_options.ignore.ignore_diagonal_text` |
| `disable_ocr` | `processing_options.ignore.ignore_text_in_image` |
| `remove_hidden_text` | `processing_options.ignore.ignore_hidden_text` |

### Processing control

| v1 | v2 |
|----|-----|
| `job_timeout_in_seconds` | `processing_control.timeouts.base_in_seconds` |
| `job_timeout_extra_time_per_page_in_seconds` | `processing_control.timeouts.extra_time_per_page_in_seconds` |
| `page_error_tolerance` | `processing_control.job_failure_conditions.allowed_page_failure_ratio` |

### Removed in v2

`gpt4o_mode`, `gpt4o_api_key`, `premium_mode`, `fast_mode`, `continuous_mode`, `vendor_multimodal_api_key`, `azure_openai_*`, `disable_image_extraction`, `hide_headers`, `hide_footers`, `page_header_prefix`, `page_footer_prefix`, `page_prefix`, `page_separator`, `input_s3_path`, `output_s3_path_prefix`, `extract_layout`
