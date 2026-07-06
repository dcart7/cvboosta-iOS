from __future__ import annotations

from fastapi import FastAPI

from .config import resolved_database_url
from .database import Base, make_engine, make_session_factory
from .routers import auth, billing, health, history, seo_content, site_metadata, tracker


def create_app(database_url: str | None = None) -> FastAPI:
    app = FastAPI(
        title="CVBoosta Backend Harness",
        version="1.1.16",
        summary="Local development API for auth, tracker sync, billing status, and history stubs.",
    )

    engine = make_engine(resolved_database_url(database_url))
    Base.metadata.create_all(engine)
    app.state.engine = engine
    app.state.session_factory = make_session_factory(engine)

    app.include_router(health.router)
    app.include_router(site_metadata.router)
    app.include_router(seo_content.router)
    app.include_router(auth.router)
    app.include_router(billing.router)
    app.include_router(history.router)
    app.include_router(tracker.router)

    return app


app = create_app()
