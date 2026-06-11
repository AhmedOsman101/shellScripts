#!/usr/bin/env python3
"""
pdfx - Extract full context from a PDF for coding agents.

Outputs: metadata, outline, hyperlinks, and text per page
with lightweight heading detection.
Tables are included by default (use --no-tables to disable).
Falls back to OCR via ocrmypdf when no text layer is detected.

Usage:
  uv run pdfx.py file.pdf
  uv run pdfx.py file.pdf > context.txt
  uv run pdfx.py file.pdf --ocr-output ./ocr.pdf
  uv run pdfx.py file.pdf --chunk 12000
  uv run pdfx.py file.pdf --text
  uv run pdfx.py file.pdf --no-tables
"""

import sys
import re
import os
import shutil
import subprocess
import tempfile
import argparse
import contextlib
from pathlib import Path

import fitz

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


# --- Extraction ---


def _get_text_silent(page: fitz.Page) -> str:
  """Extract text while suppressing fitz stdout noise (pymupdf_layout suggestion)."""
  with contextlib.redirect_stdout(open(os.devnull, "w", encoding="utf-8")):
    return page.get_text(sort=True) or ""


def extract_metadata(fitz_doc: fitz.Document) -> dict:
  meta = fitz_doc.metadata or {}
  return {k: v for k, v in meta.items() if v}


def extract_outline(fitz_doc: fitz.Document) -> list[dict]:
  toc = fitz_doc.get_toc(simple=True)
  return [{"level": lvl, "title": title, "page": page} for lvl, title, page in toc]


def extract_links(fitz_doc: fitz.Document) -> dict[int, list[str]]:
  result: dict[int, list[str]] = {}
  for page in fitz_doc:
    seen: set[str] = set()
    uris: list[str] = []
    for link in page.get_links():
      if link.get("kind") == fitz.LINK_URI and link.get("uri"):
        uri: str = link["uri"]
        if uri not in seen:
          seen.add(uri)
          uris.append(uri)
    if uris:
      num = page.number
      if isinstance(num, int):
        result[num + 1] = uris
  return result


def extract_tables(fitz_doc: fitz.Document) -> dict[int, list[list]]:
  """Extract tables using fitz's find_tables()."""
  result: dict[int, list[list]] = {}
  for page_num in range(fitz_doc.page_count):
    page = fitz_doc[page_num]
    with contextlib.redirect_stdout(open(os.devnull, "w", encoding="utf-8")):
      tables = page.find_tables()
    if tables.tables:
      page_tables: list[list] = []
      for t in tables.tables:
        data = t.extract()
        if data:
          page_tables.append([[str(cell or "").strip() for cell in row] for row in data])
      if page_tables:
        result[page_num + 1] = page_tables
  return result


def get_table_headers_per_page(fitz_tables: dict[int, list[list]]) -> dict[int, set[str]]:
  """Extract table header text lines to skip during heading detection."""
  result: dict[int, set[str]] = {}
  for page_num, tables in fitz_tables.items():
    headers: set[str] = set()
    for table in tables:
      if table and table[0]:
        # Full header row as a line
        header_line = " ".join(str(cell or "").strip() for cell in table[0])
        header_normalized = re.sub(r"\s+", " ", header_line).lower()
        if header_normalized:
          headers.add(header_normalized)
        # Individual header cells
        for cell in table[0]:
          cell_text = str(cell or "").strip().lower()
          if cell_text and len(cell_text) <= 50:
            headers.add(cell_text)
    if headers:
      result[page_num] = headers
  return result


def is_valid_table(table: list[list[str]]) -> bool:
  if not table or not table[0]:
    return False
  if len(table[0]) < 2:
    return False
  cells = [cell for row in table for cell in row]
  filled = sum(1 for c in cells if c and c.strip())
  if filled / max(len(cells), 1) < 0.5:
    return False
  joined = " ".join(cells)
  if "----" in joined or "---" in joined:
    return False
  return True


def table_overlaps_text(table, text: str) -> bool:
  flat = " ".join(cell.strip() for row in table for cell in row if cell)
  table_flat = re.sub(r"\s+", " ", flat)
  text_flat = re.sub(r"\s+", " ", text)
  return table_flat[:200] in text_flat


def table_hash(table):
  return tuple(tuple(cell or "" for cell in row) for row in table)


def normalize_text(text: str) -> str:
  text = re.sub(r"\n{3,}", "\n\n", text)
  lines = text.splitlines()
  lines = [re.sub(r" {2,}", " ", line).strip() for line in lines]
  lines = [line for line in lines if line]
  return "\n".join(lines)


def extract_text_by_page(fitz_doc: fitz.Document) -> dict[int, str]:
  result: dict[int, str] = {}
  for page_num in range(fitz_doc.page_count):
    result[page_num + 1] = normalize_text(_get_text_silent(fitz_doc[page_num]))
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


def format_table(table: list[list]) -> str:
  if not table:
    return ""

  # Normalize cells
  rows = [[str(cell or "").strip() for cell in row] for row in table]

  # Column widths
  col_count = max(len(row) for row in rows)
  widths = [0] * col_count
  for row in rows:
    for i, cell in enumerate(row):
      if i < col_count:
        widths[i] = max(widths[i], len(cell))

  def render_row(row: list[str]) -> str:
    padded = [
        row[i].ljust(widths[i]) if i < len(row) else " " * widths[i]
        for i in range(col_count)
    ]
    return "  | " + " | ".join(padded) + " |"

  separator = "  |" + "|".join("-" * (w + 2) for w in widths) + "|"

  lines = [render_row(rows[0]), separator]
  for row in rows[1:]:
    lines.append(render_row(row))
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
      seen: set = set()
      valid_tables: list = []
      for table in page_tables:
        h = table_hash(table)
        if h in seen:
          continue
        seen.add(h)
        if not is_valid_table(table):
          continue
        if len(table) <= 2 and table_overlaps_text(table, text_by_page[page_num]):
          continue
        valid_tables.append(table)
      if valid_tables:
        lines.append("\n### Tables" if markdown else "\n[Tables]")
        for i, table in enumerate(valid_tables, 1):
          if len(valid_tables) > 1:
            lines.append(f"  (table {i})")
          lines.append(format_table(table))

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
) -> None:
  fitz_doc = fitz.open(pdf_path)
  page_count = fitz_doc.page_count
  scanned = not has_text_layer(fitz_doc)
  ocr_used = False
  ocr_tmp: Path | None = None

  if scanned:
    if not shutil.which("ocrmypdf"):
      print(
          "WARNING: No text layer detected and ocrmypdf is not installed.\n"
          "         Install ocrmypdf: https://ocrmypdf.readthedocs.io",
          file=sys.stderr,
      )
    else:
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
        page_count = fitz_doc.page_count
        scanned = False
        ocr_used = True
        ocr_tmp = target if cleanup else None
        print(f"OCR complete. Using: {target}", file=sys.stderr)
      else:
        print("OCR failed. Text and table extraction will be empty.", file=sys.stderr)
        if cleanup:
          target.unlink(missing_ok=True)

  metadata = extract_metadata(fitz_doc)
  outline = extract_outline(fitz_doc)
  links = extract_links(fitz_doc)

  if not scanned:
    tables = extract_tables(fitz_doc)
    table_headers = get_table_headers_per_page(tables)
    text_by_page = extract_text_by_page(fitz_doc)
  else:
    tables = {}
    table_headers = {}
    text_by_page = {}

  fitz_doc.close()

  if ocr_tmp:
    ocr_tmp.unlink(missing_ok=True)

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
  if scanned:
    print("  (skipped - no text layer and OCR unavailable)")
  elif not text_by_page:
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

  args = parser.parse_args()

  if not args.file.exists():
    parser.error(f"file not found: {args.file}")

  # Default: markdown=True, show_tables=True
  markdown = not args.text
  show_tables = not args.no_tables

  process(args.file, args.ocr_output, args.chunk, markdown, show_tables)


if __name__ == "__main__":
  main()
