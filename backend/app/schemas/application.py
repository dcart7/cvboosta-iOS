from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class ApplicationCreate(BaseModel):
    company: str
    role: str
    status: str = "applied"
    source: str | None = None
    salary_band: str | None = None
    applied_at: datetime | None = None
    interview_at: datetime | None = None
    notes: str | None = None
    resume_used: str | None = None
    job_link: str | None = None


class ApplicationUpdate(BaseModel):
    company: str | None = None
    role: str | None = None
    status: str | None = None
    source: str | None = None
    salary_band: str | None = None
    applied_at: datetime | None = None
    interview_at: datetime | None = None
    notes: str | None = None
    resume_used: str | None = None
    job_link: str | None = None


class ApplicationResponse(BaseModel):
    id: UUID
    company: str
    role: str
    status: str
    source: str | None
    applied_at: datetime
    interview_at: datetime | None = None

    class Config:
        from_attributes = True
