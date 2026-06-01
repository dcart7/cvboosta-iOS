from io import BytesIO

try:
    from pypdf import PdfReader
except ImportError:  # pragma: no cover - optional at import time for limited test environments
    PdfReader = None


def parse_pdf_text(file_path: str) -> str:
    if PdfReader is None:
        raise RuntimeError("pypdf is not installed")

    reader = PdfReader(file_path)
    text_parts: list[str] = []

    for page in reader.pages:
        text_parts.append(page.extract_text() or "")

    return "\n".join(text_parts).strip()


def parse_pdf_bytes(content: bytes) -> str:
    if PdfReader is None:
        raise RuntimeError("pypdf is not installed")

    reader = PdfReader(BytesIO(content))
    text_parts: list[str] = []

    for page in reader.pages:
        text_parts.append(page.extract_text() or "")

    return "\n".join(text_parts).strip()
