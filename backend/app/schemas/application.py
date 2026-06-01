from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class ApplicationCreate(BaseModel):
    company: str
    role: str
    status: str = "applied"
    source: str | None = None
    salary_band: str | None = None
    interview_at: datetime | None = None


class ApplicationResponse(BaseModel):
    id: UUID
    company: str
    role: str
    status: str
    source: str | None
    applied_at: datetime

    class Config:
        from_attributes = True
