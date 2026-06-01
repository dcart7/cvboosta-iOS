from datetime import datetime
from uuid import UUID

from sqlalchemy.orm import Session

from app.db.models import Application, Resume, ResumeScan, Subscription, User
from app.schemas.auth import (
    ApplicationSnapshot,
    AuthMeResponse,
    AuthUser,
    ResumeScanSnapshot,
    ResumeSnapshot,
    SubscriptionSnapshot,
    UsageLimitsSnapshot,
)

FREE_DAILY_SCAN_LIMIT = 1


def get_active_subscription(db: Session, user_id: UUID) -> Subscription | None:
    now = datetime.utcnow()
    subscription = (
        db.query(Subscription)
        .filter(Subscription.user_id == user_id, Subscription.is_active.is_(True))
        .order_by(Subscription.expires_at.desc())
        .first()
    )
    if subscription is None:
        return None

    if subscription.expires_at is not None and subscription.expires_at < now:
        return None

    return subscription


def usage_limits_snapshot(db: Session, user_id: UUID) -> UsageLimitsSnapshot:
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    used_today = (
        db.query(ResumeScan)
        .join(Resume, Resume.id == ResumeScan.resume_id)
        .filter(Resume.user_id == user_id, ResumeScan.created_at >= today_start)
        .count()
    )
    subscription = get_active_subscription(db, user_id)
    is_premium = subscription is not None

    if is_premium:
        return UsageLimitsSnapshot(
            plan="premium",
            scans_daily_limit=None,
            scans_used_today=used_today,
            scans_remaining_today=None,
        )

    remaining = max(FREE_DAILY_SCAN_LIMIT - used_today, 0)
    return UsageLimitsSnapshot(
        plan="free",
        scans_daily_limit=FREE_DAILY_SCAN_LIMIT,
        scans_used_today=used_today,
        scans_remaining_today=remaining,
    )


def build_auth_me_response(db: Session, user: User) -> AuthMeResponse:
    subscription = get_active_subscription(db, user.id)
    usage = usage_limits_snapshot(db, user.id)

    resumes = (
        db.query(Resume)
        .filter(Resume.user_id == user.id)
        .order_by(Resume.created_at.desc())
        .limit(25)
        .all()
    )

    scans = (
        db.query(ResumeScan, Resume.file_name)
        .join(Resume, Resume.id == ResumeScan.resume_id)
        .filter(Resume.user_id == user.id)
        .order_by(ResumeScan.created_at.desc())
        .limit(50)
        .all()
    )

    applications = (
        db.query(Application)
        .filter(Application.user_id == user.id)
        .order_by(Application.applied_at.desc())
        .limit(50)
        .all()
    )

    return AuthMeResponse(
        user=AuthUser(
            id=user.id,
            email=user.email,
            display_name=user.display_name,
            created_at=user.created_at,
        ),
        subscription=SubscriptionSnapshot(
            entitlement=subscription.entitlement if subscription else None,
            is_active=subscription is not None,
            expires_at=subscription.expires_at if subscription else None,
            source=subscription.source if subscription else None,
        ),
        usage_limits=usage,
        saved_resumes=[
            ResumeSnapshot(id=resume.id, file_name=resume.file_name, created_at=resume.created_at)
            for resume in resumes
        ],
        scan_history=[
            ResumeScanSnapshot(
                id=scan.id,
                resume_id=scan.resume_id,
                resume_file_name=file_name,
                target_role=scan.target_role,
                ats_score=scan.ats_score,
                created_at=scan.created_at,
            )
            for scan, file_name in scans
        ],
        applications=[
            ApplicationSnapshot(
                id=application.id,
                company=application.company,
                role=application.role,
                status=application.status,
                source=application.source,
                applied_at=application.applied_at,
            )
            for application in applications
        ],
    )
