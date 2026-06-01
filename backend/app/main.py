from fastapi import FastAPI

from app.api.routes import analytics, applications, resume
from app.core.config import settings
from app.db.session import Base, engine

Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.app_name)

app.include_router(resume.router, prefix="/v1/resume", tags=["resume"])
app.include_router(applications.router, prefix="/v1/applications", tags=["applications"])
app.include_router(analytics.router, prefix="/v1/analytics", tags=["analytics"])


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
