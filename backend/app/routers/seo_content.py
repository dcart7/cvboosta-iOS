from __future__ import annotations

from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse

from ..seo import LIBRARY_ORDER, load_manifest, pages_by_family, pages_by_url, render_library_index, render_seo_page


router = APIRouter(tags=["seo-content"])


def ensure_seo_content_exists() -> None:
    if not load_manifest():
        raise HTTPException(status_code=404, detail="SEO content pack not found.")


def library_response(family: str) -> HTMLResponse:
    ensure_seo_content_exists()
    if family not in LIBRARY_ORDER:
        raise HTTPException(status_code=404, detail="SEO library not found.")
    if not pages_by_family().get(family):
        raise HTTPException(status_code=404, detail="SEO library is empty.")
    return HTMLResponse(render_library_index(family))


def page_response(url_path: str) -> HTMLResponse:
    ensure_seo_content_exists()
    if url_path not in pages_by_url():
        raise HTTPException(status_code=404, detail="SEO page not found.")
    return HTMLResponse(render_seo_page(url_path))


@router.get("/ats", include_in_schema=False, response_class=HTMLResponse)
def ats_index() -> HTMLResponse:
    return library_response("ats")


@router.get("/ats/{slug}", include_in_schema=False, response_class=HTMLResponse)
def ats_page(slug: str) -> HTMLResponse:
    return page_response(f"/ats/{slug}")


@router.get("/ats-comparisons", include_in_schema=False, response_class=HTMLResponse)
def ats_comparisons_index() -> HTMLResponse:
    return library_response("ats-comparisons")


@router.get("/ats-comparisons/{slug}", include_in_schema=False, response_class=HTMLResponse)
def ats_comparisons_page(slug: str) -> HTMLResponse:
    return page_response(f"/ats-comparisons/{slug}")


@router.get("/resume-keywords", include_in_schema=False, response_class=HTMLResponse)
def resume_keywords_index() -> HTMLResponse:
    return library_response("resume-keywords")


@router.get("/resume-keywords/{slug}", include_in_schema=False, response_class=HTMLResponse)
def resume_keywords_page(slug: str) -> HTMLResponse:
    return page_response(f"/resume-keywords/{slug}")


@router.get("/skills", include_in_schema=False, response_class=HTMLResponse)
def skills_index() -> HTMLResponse:
    return library_response("skills")


@router.get("/skills/{slug}", include_in_schema=False, response_class=HTMLResponse)
def skills_page(slug: str) -> HTMLResponse:
    return page_response(f"/skills/{slug}")


@router.get("/tools", include_in_schema=False, response_class=HTMLResponse)
def tools_index() -> HTMLResponse:
    return library_response("tools")


@router.get("/tools/{slug}", include_in_schema=False, response_class=HTMLResponse)
def tools_page(slug: str) -> HTMLResponse:
    return page_response(f"/tools/{slug}")


@router.get("/datasets", include_in_schema=False, response_class=HTMLResponse)
def datasets_index() -> HTMLResponse:
    return library_response("datasets")


@router.get("/datasets/{slug}", include_in_schema=False, response_class=HTMLResponse)
def datasets_page(slug: str) -> HTMLResponse:
    return page_response(f"/datasets/{slug}")
