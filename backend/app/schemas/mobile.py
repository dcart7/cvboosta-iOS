from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class ResumeListItem(BaseModel):
    id: UUID
    file_name: str
    created_at: datetime


class ResumeScanListItem(BaseModel):
    id: UUID
    resume_id: UUID
    resume_file_name: str
    target_role: str
    ats_score: int
    created_at: datetime


class TailoringGenerateRequest(BaseModel):
    resume_id: UUID | None = None
    resume_text: str | None = None
    job_title: str = Field(min_length=2, max_length=120)
    company_name: str | None = Field(default=None, max_length=120)
    job_description: str = Field(min_length=40)
    tone: str = Field(min_length=3, max_length=32)


class TailoringGenerateResponse(BaseModel):
    tailored_summary: str
    bullet_rewrites: list[str]
    missing_keywords: list[str]
    cover_letter: str


class SubscriptionStatusResponse(BaseModel):
    entitlement: str | None
    is_active: bool
    expires_at: datetime | None
    source: str | None
    plan: str
    scans_daily_limit: int | None
    scans_remaining_today: int | None
