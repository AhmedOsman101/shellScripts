#!/usr/bin/env python3
"""
pdfx - Extract full context from a PDF for coding agents.

Outputs: metadata, outline, hyperlinks, tables (inline per page),
and text per page with lightweight heading detection.
Falls back to OCR via ocrmypdf when no text layer is detected.

Usage:
  uv run pdfx.py file.pdf
  uv run pdfx.py file.pdf > context.txt
  uv run pdfx.py file.pdf --ocr-output ./ocr.pdf
  uv run pdfx.py file.pdf --chunk 12000
  uv run pdfx.py file.pdf --markdown
"""

import sys
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


# --- Extraction ---


def extract_metadata(fitz_doc: fitz.Document) -> dict:
  meta = fitz_doc.metadata or {}
  return {k: v for k, v in meta.items() if v}


def extract_outline(fitz_doc: fitz.Document) -> list[dict]:
  toc = fitz_doc.get_toc(simple=True)
  return [{"level": lvl, "title": title, "page": page} for lvl, title, page in toc]


def extract_links(fitz_doc: fitz.Document) -> dict[int, list[str]]:
  result: dict[int, list[str]] = {}
  for page in fitz_doc:
    uris = [
        link["uri"] for link in page.get_links()
        if link.get("kind") == fitz.LINK_URI and link.get("uri")
    ]
    if uris:
      # result[page.number + 1] = uris
      num = page.number
      if isinstance(num, int):
        result[num + 1] = uris
  return result


def extract_tables(plumber_pdf: pdfplumber.PDF) -> dict[int, list[list]]:
  result: dict[int, list[list]] = {}
  for page in plumber_pdf.pages:
    tables = page.extract_tables()
    if tables:
      result[page.page_number] = tables
  return result


def extract_text_by_page(plumber_pdf: pdfplumber.PDF) -> dict[int, str]:
  result: dict[int, str] = {}
  for page in plumber_pdf.pages:
    text = page.extract_text(layout=True) or ""
    result[page.page_number] = text.strip()
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

  # avoid common code / protocol lines
  if "/" in stripped or stripped.startswith(
      ("GET ", "POST ", "PUT ", "DELETE ", "HTTP")
  ):
    return False

  if stripped.isupper() and len(stripped) > 3:
    return True

  if stripped.endswith(":") and " " not in stripped.rstrip(":"):
    return True

  return False


def format_page_text(text: str) -> str:
  lines = text.splitlines()
  out = []
  for line in lines:
    if is_heading(line):
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
) -> None:
  buffer_len = 0
  chunk_index = 1

  for page_num in sorted(text_by_page):
    text = format_page_text(text_by_page[page_num]
                            ) if text_by_page[page_num] else "  (empty)"
    page_tables = tables.get(page_num, [])
    page_links = links.get(page_num, [])

    header = f"\n## Page {page_num}" if markdown else f"\n--- Page {page_num} ---"
    lines: list[str] = [header, text]

    if page_links:
      lines.append("\n### Links" if markdown else "\n[Links]")
      for uri in page_links:
        lines.append(f"  {uri}")

    if page_tables:
      lines.append("\n### Tables" if markdown else "\n[Tables]")
      for i, table in enumerate(page_tables, 1):
        if len(page_tables) > 1:
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

  plumber_pdf = pdfplumber.open(fitz_doc.name)

  metadata = extract_metadata(fitz_doc)
  outline = extract_outline(fitz_doc)
  links = extract_links(fitz_doc)
  tables = extract_tables(plumber_pdf) if not scanned else {}
  text_by_page = extract_text_by_page(plumber_pdf) if not scanned else {}

  plumber_pdf.close()
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
    print_pages(text_by_page, tables, links, chunk_size, markdown)


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
      "--markdown",
      action="store_true",
      help="Output in markdown format",
  )

  args = parser.parse_args()

  if not args.file.exists():
    parser.error(f"file not found: {args.file}")

  process(args.file, args.ocr_output, args.chunk, args.markdown)


if __name__ == "__main__":
  main()
