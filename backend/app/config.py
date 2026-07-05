from __future__ import annotations

import os
from pathlib import Path


def default_database_url() -> str:
    database_path = Path(__file__).resolve().parents[1] / "cvboosta_dev.sqlite3"
    return f"sqlite+pysqlite:///{database_path}"


def resolved_database_url(override: str | None = None) -> str:
    return override or os.getenv("DATABASE_URL") or default_database_url()
