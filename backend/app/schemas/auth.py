from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class RegisterRequest(BaseModel):
    email: str = Field(min_length=5, max_length=255)
    password: str = Field(min_length=8, max_length=128)
    display_name: str | None = Field(default=None, min_length=1, max_length=120)


class LoginRequest(BaseModel):
    email: str = Field(min_length=5, max_length=255)
    password: str = Field(min_length=8, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=20)


class LogoutRequest(BaseModel):
    refresh_token: str | None = None


class ForgotPasswordRequest(BaseModel):
    email: str = Field(min_length=5, max_length=255)


class ForgotPasswordResponse(BaseModel):
    message: str
    reset_token_preview: str | None = None


class AuthUser(BaseModel):
    id: UUID
    email: str | None
    display_name: str | None
    created_at: datetime


class SubscriptionSnapshot(BaseModel):
    entitlement: str | None
    is_active: bool
    expires_at: datetime | None
    source: str | None


class UsageLimitsSnapshot(BaseModel):
    plan: str
    scans_daily_limit: int | None
    scans_used_today: int
    scans_remaining_today: int | None


class ResumeSnapshot(BaseModel):
    id: UUID
    file_name: str
    created_at: datetime


class ResumeScanSnapshot(BaseModel):
    id: UUID
    resume_id: UUID
    resume_file_name: str
    target_role: str
    ats_score: int
    created_at: datetime


class ApplicationSnapshot(BaseModel):
    id: UUID
    company: str
    role: str
    status: str
    source: str | None
    applied_at: datetime


class AuthMeResponse(BaseModel):
    user: AuthUser
    subscription: SubscriptionSnapshot
    usage_limits: UsageLimitsSnapshot
    saved_resumes: list[ResumeSnapshot]
    scan_history: list[ResumeScanSnapshot]
    applications: list[ApplicationSnapshot]


class AuthTokenEnvelope(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    me: AuthMeResponse
