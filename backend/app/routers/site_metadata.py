from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import PlainTextResponse


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
