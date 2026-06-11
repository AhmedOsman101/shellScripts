#!/usr/bin/env python3
"""
pdfx - Extract full context from a PDF for coding agents.

Outputs: metadata, outline, hyperlinks, and text per page
with lightweight heading detection.
Tables are included by default (use --no-tables to disable).
Falls back to OCR (tesseract or rapidocr) when no text layer is detected.

Usage:
  uv run pdfx.py file.pdf
  uv run pdfx.py file.pdf > context.txt
  uv run pdfx.py file.pdf --ocr-output ./ocr.pdf
  uv run pdfx.py file.pdf --chunk 12000
  uv run pdfx.py file.pdf --text
  uv run pdfx.py file.pdf --no-tables
  uv run pdfx.py file.pdf --ocr-engine rapidocr
"""

import sys
import re
import os
import shutil
import subprocess
import tempfile
import argparse
from pathlib import Path

import fitz
import pdfplumber

# --- OCR ---


def has_text_layer(fitz_doc: fitz.Document) -> bool:
  for page in fitz_doc:
    if page.get_text().strip():
      return True
  return False


def run_ocr(input_path: Path, output_path: Path) -> bool:
  if not shutil.which("ocrmypdf"):
    return False
  try:
    subprocess.run(
        ["ocrmypdf", "--skip-text", "--quiet",
         str(input_path),
         str(output_path)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return True
  except subprocess.CalledProcessError:
    return False


def ocr_with_rapidocr(fitz_doc: fitz.Document, dpi: int = 300) -> dict[int, str]:
  """OCR each page of a fitz doc using system-installed rapidocr-onnxruntime."""
  import sys as _sys
  _sys.path.append("/usr/lib/python3.14/site-packages")
  from rapidocr_onnxruntime import RapidOCR

  engine = RapidOCR()
  result: dict[int, str] = {}

  for i in range(len(fitz_doc)):
    page = fitz_doc[i]
    page_num = i + 1

    pix = page.get_pixmap(dpi=dpi)
    img_bytes = pix.tobytes("png")

    blocks, _ = engine(img_bytes)
    if blocks:
      blocks.sort(key=lambda b: b[0][1])
      lines = []
      for _, text, conf in blocks:
        text = text.strip()
        if text and conf > 0.3:
          lines.append(text)
      result[page_num] = normalize_text("\n".join(lines)) if lines else ""
    else:
      result[page_num] = ""

  return result


def extract_metadata_fitz(fitz_doc: fitz.Document) -> dict:
  meta = fitz_doc.metadata or {}
  return {k: v for k, v in meta.items() if v}


# --- Extraction ---


def extract_outline(fitz_doc: fitz.Document) -> list[dict]:
  toc = fitz_doc.get_toc(simple=True)
  return [{"level": lvl, "title": title, "page": page} for lvl, title, page in toc]


def get_table_headers(table_objs: dict[int, list]) -> dict[int, set[str]]:
  """Extract table header text lines from pdfplumber table data (list[list[str]])."""
  result: dict[int, set[str]] = {}
  for page_num, tables in table_objs.items():
    headers: set[str] = set()
    for t_data in tables:
      if not t_data or not t_data[0]:
        continue
      header_line = " ".join(str(cell or "").strip() for cell in t_data[0])
      header_normalized = re.sub(r"\s+", " ", header_line).lower()
      if header_normalized:
        headers.add(header_normalized)
      for cell in t_data[0]:
        cell_text = str(cell or "").strip().lower()
        if cell_text and len(cell_text) <= 50:
          headers.add(cell_text)
    if headers:
      result[page_num] = headers
  return result


def _normalize_pua(text: str) -> str:
  """Replace Private Use Area characters with their ASCII equivalents.

  Some PDF fonts encode common glyphs (parens, math, list markers) as PUA
  codepoints. pdfplumber extracts them verbatim, producing garbled output.
  """
  _PUA_MAP = {
      "\ue072": "1", "\ue073": "2", "\ue074": "3",
      "\ue075": "4", "\ue076": "5",
      "\ue081": "(", "\ue082": ")",
      "\ue088": "-", "\ue089": "-",
      "\ue092": ":", "\ue094": " ",
      "\ue09d": "+", "\ue09f": "x",
      "\ue0a3": "~", "\ue1d7": "->",
  }
  for ch, repl in _PUA_MAP.items():
    text = text.replace(ch, repl)
  return text


def normalize_text(text: str) -> str:
  text = re.sub(r"\n{3,}", "\n\n", text)
  lines = text.splitlines()
  lines = [re.sub(r" {2,}", " ", line).strip() for line in lines]
  lines = [line for line in lines if line]
  return "\n".join(lines)


# --- pdfplumber Extraction ---


def extract_metadata_plumber(plumber_doc) -> dict:
  meta = plumber_doc.metadata or {}
  result = {}
  for k, v in meta.items():
    if v and k != "producer":
      result[k] = v
  return result


def extract_links_plumber(plumber_doc) -> dict[int, list[str]]:
  result: dict[int, list[str]] = {}
  for i, page in enumerate(plumber_doc.pages):
    seen: set[str] = set()
    uris: list[str] = []
    for link in page.hyperlinks or []:
      uri = link.get("uri", "")
      if not uri or uri in seen:
        continue
      # Skip internal PDF anchors – not useful for coding agents
      if uri.startswith("af://") or uri.startswith("#"):
        continue
      seen.add(uri)
      uris.append(uri)
    if uris:
      result[i + 1] = uris
  return result


def _is_valid_table_plumber(table_data: list[list[str]]) -> bool:
  if not table_data or not table_data[0]:
    return False
  if len(table_data[0]) < 2:
    return False
  cells = [cell for row in table_data for cell in row if cell]
  filled = sum(1 for c in cells if c.strip())
  if filled / max(len(cells), 1) < 0.5:
    return False
  joined = " ".join(cells)
  if "----" in joined or "---" in joined:
    return False
  # Reject single-column-heavy tables that are likely code blocks or form fields
  col_counts = [len(row) for row in table_data]
  if len(set(col_counts)) == 1 and col_counts[0] == 2:
    # 2-column table with many empty cells in second column = likely code block
    second_col_empty = sum(1 for row in table_data if not row[1].strip())
    if second_col_empty / max(len(table_data), 1) > 0.5:
      return False
  return True


def _find_tables_with_fallback(page) -> list:
  """Try default line-based detection, then fall back to text-based strategy."""
  tables = page.find_tables()
  if tables:
    return list(tables)
  # Fallback: text-based strategy for tables without drawn borders
  table_settings = {
      "vertical_strategy": "text",
      "horizontal_strategy": "text",
      "min_words_vertical": 3,
      "min_words_horizontal": 1,
  }
  tables = page.find_tables(table_settings)
  return list(tables) if tables else []


def extract_tables_plumber(plumber_doc) -> dict[int, list]:
  result: dict[int, list] = {}
  for i, page in enumerate(plumber_doc.pages):
    tables = _find_tables_with_fallback(page)
    if not tables:
      continue
    page_tables: list = []
    for t in tables:
      data = t.extract()
      if data:
        processed = [[_normalize_pua(str(cell or "")).strip() for cell in row] for row in data]
        if _is_valid_table_plumber(processed):
          page_tables.append(processed)
    if page_tables:
      result[i + 1] = page_tables
  return result


def _format_plumber_table(table_data: list[list[str]]) -> str:
  """Render pdfplumber table data as markdown."""
  if not table_data:
    return ""
  # Build markdown table
  header = table_data[0]
  lines = []
  lines.append("| " + " | ".join(str(c or "") for c in header) + " |")
  lines.append("| " + " | ".join("---" for _ in header) + " |")
  for row in table_data[1:]:
    lines.append("| " + " | ".join(str(c or "") for c in row) + " |")
  return "\n".join(lines)


def _plumber_has_text_layer(plumber_doc) -> bool:
  """Check if any page has extractable text."""
  for page in plumber_doc.pages:
    text = page.extract_text(x_tolerance=3, y_tolerance=3) or ""
    if text.strip():
      return True
  return False


def extract_text_by_page_plumber(plumber_doc, table_objs: dict[int, list] | None = None) -> dict[int, str]:
  result: dict[int, str] = {}
  for i, page in enumerate(plumber_doc.pages):
    page_num = i + 1
    if table_objs and page_num in table_objs:
      # Get ALL table bounding boxes on this page to exclude from text
      all_tables = _find_tables_with_fallback(page)
      table_bboxes = [t.bbox for t in all_tables]

      if table_bboxes:
        # Build y-position -> placeholder mapping (table top y -> placeholder text)
        table_placeholders: dict[float, str] = {}
        for t_idx, bbox in enumerate(table_bboxes, 1):
          y_pos = round(bbox[1], 1)  # top of table
          table_placeholders[y_pos] = f"(table {t_idx})"

        # Extract words and filter out those inside table regions
        lines_by_y: dict[float, list[str]] = {}
        for word in page.extract_words(x_tolerance=3, y_tolerance=3):
          word_in_table = False
          for bbox in table_bboxes:
            x0, top, x1, bottom = bbox
            if (word["x0"] >= x0 - 2 and word["x1"] <= x1 + 2 and
                word["top"] >= top - 2 and word["bottom"] <= bottom + 2):
              word_in_table = True
              break
          if not word_in_table:
            y_key = round(word["top"], 1)
            lines_by_y.setdefault(y_key, []).append(word["text"])
        # Insert table placeholders at their y-positions
        for y_pos, placeholder in table_placeholders.items():
          # Find the closest y-position to insert the placeholder
          lines_by_y.setdefault(y_pos, []).insert(0, placeholder)
        # Sort by y position and join words in each line
        sorted_lines = [" ".join(words) for _, words in sorted(lines_by_y.items())]
        text = "\n".join(sorted_lines)
      else:
        text = page.extract_text(x_tolerance=3, y_tolerance=3) or ""
    else:
      text = page.extract_text(x_tolerance=3, y_tolerance=3) or ""
    result[page_num] = normalize_text(_normalize_pua(text))
  return result


# --- Formatting ---


def format_metadata(meta: dict, page_count: int) -> str:
  lines = [f"  pages: {page_count}"]
  for k, v in meta.items():
    lines.append(f"  {k}: {v}")
  return "\n".join(lines)


def format_outline(outline: list[dict]) -> str:
  if not outline:
    return "  (none)"
  lines = []
  for entry in outline:
    indent = "  " * entry["level"]
    lines.append(f"{indent}[p{entry['page']}] {entry['title']}")
  return "\n".join(lines)


def is_heading(line: str) -> bool:
  stripped = line.strip()

  if not stripped or len(stripped) > 120:
    return False

  lower = stripped.lower()

  # Avoid code / protocol / url lines
  if lower.startswith(("get ", "post ", "put ", "delete ", "http")):
    return False

  if "/" in stripped and "/" in stripped[:5]:
    return False

  # Numbered heading: "1. Title", "2.1 Subtitle", "3.2.1 Deep heading"
  if (re.match(r"^\d+\.\s+[A-Za-z]", stripped) or
      re.match(r"^\d+(\.\d+)+\s+[A-Za-z]", stripped)):
    if len(stripped) >= 80:
      return False
    # Label pattern: "1. Router:" — headings don't end in colons
    if stripped.endswith(":"):
      return False
    # Sentence-ending punctuation = list item, not heading ("1. Open a PC...")
    if stripped.endswith((".", ";")) and not stripped.endswith("..."):
      return False
    # Wordy list item: more than 7 words is likely a procedure step
    if len(stripped.split()) > 7:
      return False
    return True

  # Step marker: "Step 1: Place Devices"
  if re.match(r"^Step\s+\d+\s*:", stripped):
    return True

  # ALLCAPS words: "CCNA", "TCP", "OSPF" (letters only, min 4 chars)
  if len(stripped) > 3 and stripped.isupper() and all(c.isalpha() or c.isspace() for c in stripped):
    return True

  # Avoid sentence endings, bullets, emails
  if stripped[-1] in ".!?;":
    return False

  if stripped.startswith(("•", "-", "*", "http", "www.")) or "@" in stripped:
    return False

  words = stripped.split()
  if not words:
    return False

  # Single word: PascalCase (min 5 chars)
  if len(words) == 1:
    if not (4 < len(stripped) <= 45):
      return False
    if re.match(r"^\d+$", stripped):
      return False
    # Trailing colon = label, not heading ("Calculation:", "Note:")
    if stripped.endswith(":"):
      return False
    if re.search(r"[A-Z][a-z]", stripped) and stripped[0].isupper():
      return True
    return False

  return False


def format_page_text(text: str, skip_headings: set[str] | None = None) -> str:
  lines = text.splitlines()
  out = []
  for line in lines:
    stripped = line.strip().lower()
    if skip_headings and stripped in skip_headings:
      out.append(line.strip())
    elif is_heading(line):
      out.append(f"\n## {line.strip()}\n")
    else:
      out.append(line)
  return "\n".join(out)


# --- Output ---


def print_pages(
    text_by_page,
    tables,
    links,
    chunk_size,
    markdown: bool,
    show_tables: bool = False,
    skip_headings_by_page: dict[int, set[str]] | None = None,
) -> None:
  buffer_len = 0
  chunk_index = 1

  for page_num in sorted(text_by_page):
    skip = (skip_headings_by_page or {}).get(page_num)
    text = format_page_text(text_by_page[page_num], skip
                            ) if text_by_page[page_num] else "  (empty)"
    page_links = links.get(page_num, [])

    header = f"\n## Page {page_num}" if markdown else f"\n--- Page {page_num} ---"
    lines: list[str] = [header, text]

    if page_links:
      lines.append("\n### Links" if markdown else "\n[Links]")
      for uri in page_links:
        lines.append(f"  {uri}")

    if show_tables:
      page_tables = tables.get(page_num, [])
      if page_tables:
        lines.append("\n### Tables" if markdown else "\n[Tables]")
        for i, t_data in enumerate(page_tables, 1):
          if len(page_tables) > 1:
            lines.append(f"  (table {i})")
          # pdfplumber tables are list[list[str]], format as markdown
          if isinstance(t_data, list) and t_data and isinstance(t_data[0], list):
            lines.append(_format_plumber_table(t_data))

    block = "\n".join(lines)

    if chunk_size:
      if buffer_len > 0 and buffer_len + len(block) > chunk_size:
        print(
            f"\n\n--- CHUNK BREAK ({chunk_index}) ---\n"
            if markdown else f"\n=== CHUNK BREAK ({chunk_index}) ==="
        )
        chunk_index += 1
        buffer_len = 0
      buffer_len += len(block)

    print(block)


# --- Main ---


def process(
    pdf_path: Path,
    ocr_output: Path | None = None,
    chunk_size: int | None = None,
    markdown: bool = False,
    show_tables: bool = False,
    ocr_engine: str = "tesseract",
) -> None:
  import warnings
  import logging
  warnings.filterwarnings("ignore", message=".*FontBBox.*")
  logging.getLogger("pdfminer").setLevel(logging.CRITICAL)
  logging.getLogger("pdfplumber").setLevel(logging.CRITICAL)

  fitz_doc = fitz.open(pdf_path)
  scanned = not has_text_layer(fitz_doc)
  ocr_used = False
  ocr_tmp: Path | None = None

  if scanned:
    if ocr_engine == "rapidocr":
      print("No text layer detected. Using rapidocr...", file=sys.stderr)
      outline = extract_outline(fitz_doc)
      text_by_page = ocr_with_rapidocr(fitz_doc)
      metadata = extract_metadata_fitz(fitz_doc)
      page_count = len(fitz_doc)
      fitz_doc.close()
      ocr_used = True
    elif shutil.which("ocrmypdf"):
      print("No text layer detected. Running OCR...", file=sys.stderr)

      if ocr_output:
        target = ocr_output
        cleanup = False
      else:
        tmp = tempfile.NamedTemporaryFile(suffix=".pdf", delete=False)
        tmp.close()
        target = Path(tmp.name)
        cleanup = True

      if run_ocr(pdf_path, target):
        fitz_doc.close()
        fitz_doc = fitz.open(target)
        scanned = False
        ocr_used = True
        ocr_tmp = target if cleanup else None
        print(f"OCR complete. Using: {target}", file=sys.stderr)
      else:
        print("OCR failed. Text and table extraction will be empty.", file=sys.stderr)
        if cleanup:
          target.unlink(missing_ok=True)
    else:
      print(
          "WARNING: No text layer detected and no OCR engine available.\n"
          "         Install ocrmypdf or use --ocr-engine rapidocr.",
          file=sys.stderr,
      )

  # --- RapidOCR short-circuit (handles output inline) ---
  if ocr_engine == "rapidocr" and ocr_used:
    _print_output(pdf_path, ocr_used, markdown, metadata, page_count, outline,
                  text_by_page, {}, {}, chunk_size, show_tables, {})
    return

  # --- Outline from fitz (pdfplumber has no outline support) ---
  outline = extract_outline(fitz_doc)
  fitz_doc.close()

  # --- Text, tables, links, metadata via pdfplumber ---
  old_stderr = sys.stderr
  sys.stderr = open(os.devnull, "w", encoding="utf-8")
  try:
    with pdfplumber.open(pdf_path if not ocr_tmp else ocr_tmp) as plumber_doc:
      page_count = len(plumber_doc.pages)
      metadata = extract_metadata_plumber(plumber_doc)
      links = extract_links_plumber(plumber_doc)

      if not scanned:
        tables = extract_tables_plumber(plumber_doc)
        table_headers = get_table_headers(tables) if show_tables else {}
        text_by_page = extract_text_by_page_plumber(plumber_doc, tables if show_tables else None)
      else:
        tables = {}
        table_headers = {}
        text_by_page = {}
  finally:
    sys.stderr.close()
    sys.stderr = old_stderr

  if ocr_tmp:
    ocr_tmp.unlink(missing_ok=True)

  _print_output(pdf_path, ocr_used, markdown, metadata, page_count, outline,
                text_by_page, tables, links, chunk_size, show_tables, table_headers)


def _print_output(
    pdf_path: Path,
    ocr_used: bool,
    markdown: bool,
    metadata: dict,
    page_count: int,
    outline: list[dict],
    text_by_page: dict[int, str],
    tables: dict[int, list],
    links: dict[int, list[str]],
    chunk_size: int | None,
    show_tables: bool,
    table_headers: dict[int, set[str]],
) -> None:
  print(f"{'=' * 60}")
  print(f"PDF CONTEXT: {pdf_path}")
  if ocr_used:
    print("(OCR applied)")
  print(f"{'=' * 60}")
  print()

  print("# Metadata" if markdown else "=== METADATA ===")
  print(format_metadata(metadata, page_count))
  print()

  print("=== OUTLINE / BOOKMARKS ===")
  print(format_outline(outline))
  print()

  print("=== TEXT BY PAGE ===")
  if not text_by_page:
    print("  (no text extracted)")
  else:
    print_pages(text_by_page, tables, links, chunk_size, markdown, show_tables, table_headers)


def main() -> None:
  parser = argparse.ArgumentParser(
      prog="pdfx",
      description="Extract full context from a PDF for coding agents.",
      formatter_class=argparse.RawDescriptionHelpFormatter,
      epilog=(
          "Examples:\n"
          "  uv run pdfx.py file.pdf\n"
          "  uv run pdfx.py file.pdf > context.txt\n"
          "  uv run pdfx.py file.pdf --ocr-output ./ocr.pdf\n"
          "  uv run pdfx.py file.pdf --chunk 12000\n"
      ),
  )
  parser.add_argument("file", type=Path, help="Path to the PDF file")
  parser.add_argument(
      "--ocr-output",
      type=Path,
      metavar="PATH",
      help="Save the OCR'd PDF to this path instead of a temp file",
  )
  parser.add_argument(
      "--chunk",
      type=int,
      metavar="CHARS",
      help="Insert chunk break markers every N characters",
  )

  parser.add_argument(
      "--text",
      action="store_true",
      help="Output in plain text format (default is markdown)",
  )

  parser.add_argument(
      "--no-tables",
      action="store_true",
      help="Disable table extraction (tables are included by default)",
  )

  parser.add_argument(
      "--ocr-engine",
      choices=["tesseract", "rapidocr"],
      default="tesseract",
      help="OCR engine for scanned PDFs (default: tesseract)",
  )

  args = parser.parse_args()

  if not args.file.exists():
    parser.error(f"file not found: {args.file}")

  # Default: markdown=True, show_tables=True
  markdown = not args.text
  show_tables = not args.no_tables

  process(args.file, args.ocr_output, args.chunk, markdown, show_tables, args.ocr_engine)


if __name__ == "__main__":
  main()
