from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.api.routes import resume as resume_routes
from app.db.models import Resume, ResumeScan, User
from app.db.session import get_db
from app.schemas.mobile import (
    ResumeListItem,
    ResumeScanListItem,
    SubscriptionStatusResponse,
    TailoringGenerateRequest,
    TailoringGenerateResponse,
)
from app.schemas.resume import ResumeScanRequest, ResumeScanResponse
from app.services.ai_orchestrator import AIOrchestrator
from app.services.ats_engine import analyze_resume
from app.services.user_state import get_active_subscription, usage_limits_snapshot

router = APIRouter()
ai_orchestrator = AIOrchestrator()


@router.post("/resumes/scan", response_model=ResumeScanResponse)
async def scan_resume(
    target_role: str = Form(...),
    file: UploadFile | None = File(default=None),
    resume_text: str | None = Form(default=None),
    job_description: str | None = Form(default=None),
    experience_level: str | None = Form(default=None),
    target_market: str | None = Form(default=None),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ResumeScanResponse:
    if file is not None:
        return await resume_routes.scan_resume_file(
            file=file,
            target_role=target_role,
            job_description=job_description,
            experience_level=experience_level,
            target_market=target_market,
            user=user,
            db=db,
        )

    if resume_text and resume_text.strip():
        request = ResumeScanRequest(resume_text=resume_text.strip(), target_role=target_role)
        return await resume_routes.scan_resume(payload=request, user=user, db=db)

    raise HTTPException(status_code=400, detail="Provide either resume PDF file or resume_text.")


@router.get("/resumes", response_model=list[ResumeListItem])
def list_resumes(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[ResumeListItem]:
    resumes = (
        db.query(Resume)
        .filter(Resume.user_id == user.id)
        .order_by(Resume.created_at.desc())
        .limit(50)
        .all()
    )
    return [ResumeListItem(id=item.id, file_name=item.file_name, created_at=item.created_at) for item in resumes]


@router.get("/resumes/scans", response_model=list[ResumeScanListItem])
def list_resume_scans(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[ResumeScanListItem]:
    scans = (
        db.query(ResumeScan, Resume.file_name)
        .join(Resume, Resume.id == ResumeScan.resume_id)
        .filter(Resume.user_id == user.id)
        .order_by(ResumeScan.created_at.desc())
        .limit(100)
        .all()
    )

    return [
        ResumeScanListItem(
            id=scan.id,
            resume_id=scan.resume_id,
            resume_file_name=file_name,
            target_role=scan.target_role,
            ats_score=scan.ats_score,
            created_at=scan.created_at,
        )
        for scan, file_name in scans
    ]


@router.post("/tailoring/generate", response_model=TailoringGenerateResponse)
async def generate_tailoring(
    payload: TailoringGenerateRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> TailoringGenerateResponse:
    base_resume_text = payload.resume_text or ""

    if payload.resume_id is not None:
        resume = (
            db.query(Resume)
            .filter(Resume.id == payload.resume_id, Resume.user_id == user.id)
            .first()
        )
        if resume is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Resume not found.")
        base_resume_text = resume.text_content

    if not base_resume_text.strip():
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Resume content is required.")

    bullets = [line.strip(" -•\t") for line in base_resume_text.splitlines() if line.strip()]
    bullet_inputs = bullets[:5] if bullets else [base_resume_text[:180]]

    rewrite_outputs = await ai_orchestrator.rewrite_bullets(payload.job_title, bullet_inputs)
    analysis = analyze_resume(base_resume_text, payload.job_title)

    company_suffix = f" for {payload.company_name}" if payload.company_name else ""
    summary = (
        f"{payload.tone} tailored summary{company_suffix}: emphasize role-fit achievements, "
        f"quantified outcomes, and recruiter-ready clarity for {payload.job_title}."
    )

    cover_letter = (
        f"Dear Hiring Team,\n\n"
        f"I am excited to apply for the {payload.job_title}{company_suffix}. "
        f"My background aligns with your requirements, and I focus on measurable impact, "
        f"clear communication, and consistent delivery.\n\n"
        f"Best regards,\n{user.display_name or user.email or 'CVBoosta User'}"
    )

    return TailoringGenerateResponse(
        tailored_summary=summary,
        bullet_rewrites=rewrite_outputs,
        missing_keywords=analysis.keyword_gaps[:12],
        cover_letter=cover_letter,
    )


@router.get("/subscription/status", response_model=SubscriptionStatusResponse)
def subscription_status(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SubscriptionStatusResponse:
    subscription = get_active_subscription(db, user.id)
    usage = usage_limits_snapshot(db, user.id)

    return SubscriptionStatusResponse(
        entitlement=subscription.entitlement if subscription else None,
        is_active=subscription is not None,
        expires_at=subscription.expires_at if subscription else None,
        source=subscription.source if subscription else None,
        plan=usage.plan,
        scans_daily_limit=usage.scans_daily_limit,
        scans_remaining_today=usage.scans_remaining_today,
    )
