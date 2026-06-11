#!/usr/bin/env python3
"""
pdfx - Extract full context from a PDF for coding agents.

Primary: LlamaParse cloud API (markdown extraction, tables included).
Fallback: Local OCR via rapidocr/tesseract when API key missing or API fails.

Usage:
  uv run pdfx.py file.pdf
  uv run pdfx.py file.pdf > context.txt
  uv run pdfx.py file.pdf --chunk 12000
  uv run pdfx.py file.pdf --local
"""

import os
import sys
import re
import tempfile
import argparse
from pathlib import Path

import fitz
import pdfplumber
from dotenv import load_dotenv

# --- LlamaParse ---


def load_api_key() -> str | None:
  """Load LLAMA_PARSE_API_KEY from .env file."""
  env_path = Path(__file__).parent / ".env"
  if env_path.exists():
    load_dotenv(env_path)
  return os.environ.get("LLAMA_PARSE_API_KEY")


def parse_with_llamaparse(pdf_path: Path) -> str | None:
  """Upload PDF to LlamaParse and return markdown_full content."""
  try:
    from llama_cloud import LlamaCloud
    import llama_cloud
  except ImportError:
    return None

  api_key = load_api_key()
  if not api_key:
    return None

  try:
    client = LlamaCloud()

    file_obj = client.files.create(file=pdf_path, purpose="parse")

    result = client.parsing.parse(
        file_id=file_obj.id,
        tier="cost_effective",
        version="latest",
        expand=["markdown_full"],
    )

    if result.job.status == "COMPLETED":
      return result.markdown_full
    else:
      print(
          f"WARNING: LlamaParse failed with status: {result.job.status}",
          file=sys.stderr,
      )
      return None

  except llama_cloud.BadRequestError as e:
    print(f"WARNING: LlamaParse bad request: {e}", file=sys.stderr)
    return None
  except llama_cloud.AuthenticationError:
    print("WARNING: LlamaParse auth failed — check LLAMA_PARSE_API_KEY", file=sys.stderr)
    return None
  except llama_cloud.RateLimitError:
    print("WARNING: LlamaParse rate limited — try again later", file=sys.stderr)
    return None
  except llama_cloud.APIError as e:
    print(f"WARNING: LlamaParse API error: {e}", file=sys.stderr)
    return None
  except Exception as e:
    print(f"WARNING: LlamaParse error: {e}", file=sys.stderr)
    return None


# --- OCR ---


def has_text_layer(fitz_doc: fitz.Document) -> bool:
  for page in fitz_doc:
    if page.get_text().strip():
      return True
  return False


def ocr_with_tesseract(pdf_path: Path, output_path: Path) -> bool:
  """OCR a scanned PDF using rapidocr for text detection and tesseract for rendering."""
  try:
    sys.path.append("/usr/lib/python3.14/site-packages")
    from rapidocr_onnxruntime import RapidOCR
  except ImportError:
    print(
        "WARNING: rapidocr-onnxruntime not installed.\n"
        "         Install: pip install rapidocr-onnxruntime",
        file=sys.stderr,
    )
    return False

  ocr = RapidOCR()
  doc = fitz.open(pdf_path)
  out_doc = fitz.open()

  for page_num in range(doc.page_count):
    page = doc[page_num]
    pix = page.get_pixmap(dpi=300)
    img_bytes = pix.tobytes("png")

    result, _ = ocr(img_bytes)
    if not result:
      continue

    blocks = []
    for bbox, text, conf in result:
      x0, y0, x1, y1 = bbox[0][0], bbox[0][1], bbox[2][0], bbox[2][1]
      blocks.append((y0, x0, x1, y1, text))

    blocks.sort(key=lambda b: (b[0], b[1]))

    out_page = out_doc.new_page(width=page.rect.width, height=page.rect.height)
    for y0, x0, x1, y1, text in blocks:
      rect = fitz.Rect(x0, y0, x1, y1)
      out_page.insert_textbox(rect, text, fontsize=10)

  out_doc.save(str(output_path))
  out_doc.close()
  doc.close()
  return True


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


def extract_tables(plumber_pdf: pdfplumber.PDF) -> dict[int, list[list]]:
  result: dict[int, list[list]] = {}
  for page in plumber_pdf.pages:
    tables = page.extract_tables()
    if tables:
      result[page.page_number] = tables
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
  text = re.sub(r" {2,}", " ", text)
  text = re.sub(r"\n{3,}", "\n\n", text)
  return text.strip()


def extract_text_by_page(plumber_pdf: pdfplumber.PDF) -> dict[int, str]:
  result: dict[int, str] = {}
  for page in plumber_pdf.pages:
    text = page.extract_text(layout=True) or ""
    result[page.page_number] = normalize_text(text)
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

  # Avoid code / protocol / url lines
  if stripped.startswith(("GET ", "POST ", "PUT ", "DELETE ", "HTTP", "http")):
    return False

  if "/" in stripped and "/" in stripped[:5]:
    return False

  # Numbered heading like "1.7 A Simple Java Program"
  if re.match(r"^\d+\.\d+\s+[A-Z]", stripped) and len(stripped) <= 80:
    return True

  if stripped.isupper() and len(stripped) > 3:
    return True

  if stripped.endswith(":") and " " not in stripped.rstrip(":"):
    return True

  # Avoid sentence endings, bullets, emails
  if stripped[-1] in ".!?;":
    return False

  if stripped.startswith(("•", "-", "*", "http", "www.")) or "@" in stripped:
    return False

  words = stripped.split()
  if not words:
    return False

  # Single word: short, starts with uppercase
  if len(words) == 1:
    return 1 < len(stripped) <= 45 and stripped[0].isupper()

  # Multi-word (2-4): all words capitalized, short, no structural markers
  if len(words) <= 4 and len(stripped) <= 50:
    if "|" in stripped or "(" in stripped or ")" in stripped:
      return False
    if any(c.isdigit() for c in stripped):
      return False
    # Avoid label-value pairs like "Address: Cairo, Egypt"
    if ":" in stripped and not stripped.endswith(":"):
      return False
    if all(w[0].isupper() for w in words if w):
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
) -> None:
  buffer_len = 0
  chunk_index = 1

  for page_num in sorted(text_by_page):
    text = format_page_text(text_by_page[page_num]
                            ) if text_by_page[page_num] else "  (empty)"
    page_links = links.get(page_num, [])

    header = f"\n## Page {page_num}"
    lines: list[str] = [header, text]

    if page_links:
      lines.append("\n### Links")
      for uri in page_links:
        lines.append(f"  {uri}")

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
      lines.append("\n### Tables")
      for i, table in enumerate(valid_tables, 1):
        if len(valid_tables) > 1:
          lines.append(f"  (table {i})")
        lines.append(format_table(table))

    block = "\n".join(lines)

    if chunk_size:
      if buffer_len > 0 and buffer_len + len(block) > chunk_size:
        print(f"\n\n--- CHUNK BREAK ({chunk_index}) ---\n")
        chunk_index += 1
        buffer_len = 0
      buffer_len += len(block)

    print(block)


# --- Main ---


def process(
    pdf_path: Path,
    chunk_size: int | None = None,
    local_only: bool = False,
) -> None:
  # --- Try LlamaParse first ---
  if not local_only:
    print("Attempting LlamaParse...", file=sys.stderr)
    llama_md = parse_with_llamaparse(pdf_path)
    if llama_md is not None:
      print("LlamaParse succeeded.", file=sys.stderr)
      print(f"\n{'=' * 60}")
      print(f"PDF CONTEXT: {pdf_path}")
      print(f"(parsed via LlamaParse)")
      print(f"{'=' * 60}\n")
      print(llama_md)
      return
    else:
      print("LlamaParse unavailable or failed. Falling back to local OCR.", file=sys.stderr)

  # --- Local fallback ---
  fitz_doc = fitz.open(pdf_path)
  page_count = fitz_doc.page_count
  scanned = not has_text_layer(fitz_doc)
  ocr_used = False

  if scanned:
    print("No text layer detected. Running local OCR...", file=sys.stderr)

    tmp = tempfile.NamedTemporaryFile(suffix=".pdf", delete=False)
    tmp.close()
    target = Path(tmp.name)

    if ocr_with_tesseract(pdf_path, target):
      fitz_doc.close()
      fitz_doc = fitz.open(target)
      page_count = fitz_doc.page_count
      scanned = False
      ocr_used = True
      print(f"OCR complete. Using: {target}", file=sys.stderr)
    else:
      print("OCR failed. Text and table extraction will be empty.", file=sys.stderr)
      target.unlink(missing_ok=True)

  plumber_pdf = pdfplumber.open(fitz_doc.name)

  metadata = extract_metadata(fitz_doc)
  outline = extract_outline(fitz_doc)
  links = extract_links(fitz_doc)
  tables = extract_tables(plumber_pdf) if not scanned else {}
  text_by_page = extract_text_by_page(plumber_pdf) if not scanned else {}

  plumber_pdf.close()
  fitz_doc.close()

  print(f"{'=' * 60}")
  print(f"PDF CONTEXT: {pdf_path}")
  if ocr_used:
    print("(OCR applied)")
  print(f"{'=' * 60}")
  print()

  print("# Metadata")
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
    print_pages(text_by_page, tables, links, chunk_size)


def main() -> None:
  parser = argparse.ArgumentParser(
      prog="pdfx",
      description="Extract full context from a PDF for coding agents.",
      formatter_class=argparse.RawDescriptionHelpFormatter,
      epilog=(
          "Examples:\n"
          "  uv run pdfx.py file.pdf\n"
          "  uv run pdfx.py file.pdf > context.txt\n"
          "  uv run pdfx.py file.pdf --chunk 12000\n"
          "  uv run pdfx.py file.pdf --local\n"
      ),
  )
  parser.add_argument("file", type=Path, help="Path to the PDF file")
  parser.add_argument(
      "--chunk",
      type=int,
      metavar="CHARS",
      help="Insert chunk break markers every N characters",
  )
  parser.add_argument(
      "--local",
      action="store_true",
      help="Skip LlamaParse, use local OCR only",
  )

  args = parser.parse_args()

  if not args.file.exists():
    parser.error(f"file not found: {args.file}")

  process(args.file, args.chunk, args.local)


if __name__ == "__main__":
  main()
