from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class AuthRegisterRequest(BaseModel):
    email: str
    password: str
    full_name: str | None = None


class AuthLoginRequest(BaseModel):
    email: str
    password: str


class AuthForgotPasswordRequest(BaseModel):
    email: str


class AuthAppleLoginRequest(BaseModel):
    id_token: str | None = None
    access_token: str | None = None
    full_name: str | None = None
    email: str | None = None


class AuthTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    email: str


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    full_name: str | None = None
    created_at: datetime


class TrackerFolderResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    emoji: str
    created_at: datetime


class TrackerApplicationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    company: str
    role: str
    status: str
    source: str | None = None
    applied_at: datetime
    interview_at: datetime | None = None
    notes: str | None = None
    resume_used: str | None = None
    job_link: str | None = None
    folder_id: UUID | None = None
    ats_score: int | None = None
    interview_reflection_rating: int | None = None
    interview_reflection_outcome: str | None = None
    interview_reflection_notes: str | None = None
    interview_reflection_submitted_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class AuthMeResponse(BaseModel):
    user: UserResponse
    applications: list[TrackerApplicationResponse]
    tracker_folders: list[TrackerFolderResponse]
    saved_resumes: list[dict] = Field(default_factory=list)


class BillingStatusResponse(BaseModel):
    plan: str
    entitlement: str
    is_active: bool
    source: str
    scans_daily_limit: int
    scans_used_today: int
    scans_remaining_today: int
    cover_letter_daily_limit: int
    cover_letter_used_today: int
    cover_letter_remaining_today: int
    interview_prep_daily_limit: int
    interview_prep_used_today: int
    interview_prep_remaining_today: int


class HistoryItemResponse(BaseModel):
    id: int
    company: str | None = None
    role: str | None = None
    score: int
    created_at: datetime
    match_before: int | None = None
    match_after: int | None = None


class HistoryResponse(BaseModel):
    items: list[HistoryItemResponse]


class TrackerSnapshotResponse(BaseModel):
    applications: list[TrackerApplicationResponse]
    folders: list[TrackerFolderResponse]


class TrackerFolderCreateRequest(BaseModel):
    id: UUID | None = None
    name: str
    emoji: str = "🗂"
    application_ids: list[UUID] = Field(default_factory=list)


class TrackerFolderUpdateRequest(BaseModel):
    name: str | None = None
    emoji: str | None = None


class TrackerApplicationCreateRequest(BaseModel):
    id: UUID | None = None
    company: str
    role: str
    status: str
    source: str | None = "iOS"
    applied_at: datetime
    interview_at: datetime | None = None
    notes: str | None = None
    resume_used: str | None = None
    job_link: str | None = None
    folder_id: UUID | None = None
    ats_score: int | None = None
    interview_reflection_rating: int | None = None
    interview_reflection_outcome: str | None = None
    interview_reflection_notes: str | None = None
    interview_reflection_submitted_at: datetime | None = None


class TrackerApplicationUpdateRequest(BaseModel):
    company: str | None = None
    role: str | None = None
    status: str | None = None
    source: str | None = None
    applied_at: datetime | None = None
    interview_at: datetime | None = None
    notes: str | None = None
    resume_used: str | None = None
    job_link: str | None = None
    folder_id: UUID | None = None
    ats_score: int | None = None
    interview_reflection_rating: int | None = None
    interview_reflection_outcome: str | None = None
    interview_reflection_notes: str | None = None
    interview_reflection_submitted_at: datetime | None = None
