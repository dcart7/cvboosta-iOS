from fastapi import FastAPI

from app.api.routes import analytics, applications, auth, mobile, resume
from app.core.config import settings
from app.db.session import Base, engine

if settings.app_env == "dev" and settings.db_auto_create:
    # Never auto-create tables in production: the website DB is the source of truth.
    Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.app_name)

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(resume.router, prefix="/v1/resume", tags=["resume"])
app.include_router(applications.router, prefix="/v1/applications", tags=["applications"])
app.include_router(analytics.router, prefix="/v1/analytics", tags=["analytics"])
app.include_router(applications.router, prefix="/applications", tags=["applications"])
app.include_router(mobile.router, tags=["mobile"])


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
