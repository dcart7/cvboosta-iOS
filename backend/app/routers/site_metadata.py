from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import PlainTextResponse, Response

from ..config import site_base_url
from ..seo import sitemap_entries


router = APIRouter(tags=["site-metadata"])

REPO_ROOT = Path(__file__).resolve().parents[3]


def read_site_file(name: str) -> str:
    path = REPO_ROOT / name
    if not path.exists():
        raise HTTPException(status_code=404, detail=f"{name} not found.")
    return path.read_text(encoding="utf-8")


@router.get("/llms.txt", include_in_schema=False, response_class=PlainTextResponse)
def llms_txt() -> str:
    return read_site_file("llms.txt")


@router.get("/llms-full.txt", include_in_schema=False, response_class=PlainTextResponse)
def llms_full_txt() -> str:
    return read_site_file("llms-full.txt")


@router.get("/robots.txt", include_in_schema=False, response_class=PlainTextResponse)
def robots_txt() -> str:
    base_url = site_base_url()
    return "\n".join(
        [
            "User-agent: *",
            "Allow: /",
            "",
            f"Sitemap: {base_url}/sitemap.xml",
            f"# LLM context: {base_url}/llms.txt",
        ]
    )


@router.get("/sitemap.xml", include_in_schema=False)
def sitemap_xml() -> Response:
    items = "\n".join(
        [
            "  <url>"
            f"<loc>{site_base_url()}{url_path}</loc>"
            f"<lastmod>{lastmod}</lastmod>"
            "</url>"
            for url_path, lastmod in sitemap_entries()
        ]
    )
    body = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{items}\n"
        "</urlset>\n"
    )
    return Response(content=body, media_type="application/xml")
