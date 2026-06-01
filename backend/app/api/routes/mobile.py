from datetime import datetime

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.models import Resume, ResumeScan, ScanFinding, User
from app.db.session import get_db
from app.schemas.mobile import (
    ResumeListItem,
    ResumeScanListItem,
    SubscriptionStatusResponse,
    TailoringGenerateRequest,
    TailoringGenerateResponse,
)
from app.schemas.resume import ResumeScanResponse, ScanFindingDTO
from app.services.ai_orchestrator import AIOrchestrator
from app.services.ats_engine import ATSResult, analyze_resume
from app.services.pdf_parser import parse_pdf_bytes
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
    _enforce_scan_limit(db, user)

    extracted_text: str
    file_name: str

    if file is not None:
        if file.content_type not in {"application/pdf", "application/octet-stream"}:
            raise HTTPException(status_code=400, detail="Only PDF uploads are supported.")
        content = await file.read()
        if not content:
            raise HTTPException(status_code=400, detail="Uploaded file is empty.")
        try:
            extracted_text = parse_pdf_bytes(content)
        except Exception as error:
            raise HTTPException(status_code=400, detail="Invalid or unreadable PDF.") from error

        file_name = file.filename or "uploaded-resume.pdf"
    elif resume_text and resume_text.strip():
        extracted_text = resume_text.strip()
        file_name = f"inline-resume-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}.txt"
    else:
        raise HTTPException(status_code=400, detail="Provide either resume PDF file or resume_text.")

    context_suffix = _build_context_suffix(
        job_description=job_description,
        experience_level=experience_level,
        target_market=target_market,
    )
    analysis_input = f"{extracted_text}\n\n{context_suffix}" if context_suffix else extracted_text

    deterministic_result = analyze_resume(analysis_input, target_role)
    result = await ai_orchestrator.enhance_scan_result(
        resume_text=analysis_input,
        target_role=target_role,
        result=deterministic_result,
    )

    _persist_scan(
        db=db,
        user=user,
        file_name=file_name,
        text_content=analysis_input,
        target_role=target_role,
        result=result,
    )

    return _to_scan_response(result)


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
    combined_text = f"{base_resume_text}\n\n{payload.job_description}"
    analysis = analyze_resume(combined_text, payload.job_title)

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


def _build_context_suffix(
    job_description: str | None,
    experience_level: str | None,
    target_market: str | None,
) -> str:
    parts: list[str] = []
    if experience_level:
        parts.append(f"Experience Level: {experience_level}")
    if target_market:
        parts.append(f"Target Market: {target_market}")
    if job_description and job_description.strip():
        parts.append(f"Job Description: {job_description.strip()}")
    return "\n".join(parts)


def _to_scan_response(result: ATSResult) -> ResumeScanResponse:
    return ResumeScanResponse(
        ats_score=result.ats_score,
        keyword_coverage=result.keyword_coverage,
        measurable_impact_ratio=result.measurable_impact_ratio,
        readability_score=result.readability_score,
        recruiter_signal_score=result.recruiter_signal_score,
        keyword_gaps=result.keyword_gaps,
        priority_fixes=result.priority_fixes,
        weak_bullet_examples=result.weak_bullet_examples,
        rewrite_suggestions=result.rewrite_suggestions,
        findings=[
            ScanFindingDTO(
                category=f.category,
                severity=f.severity,
                message=f.message,
                suggestion=f.suggestion,
            )
            for f in result.findings
        ],
    )


def _persist_scan(
    db: Session,
    user: User,
    file_name: str,
    text_content: str,
    target_role: str,
    result: ATSResult,
) -> None:
    resume = Resume(
        user_id=user.id,
        file_name=file_name,
        text_content=text_content,
    )
    db.add(resume)
    db.flush()

    scan = ResumeScan(
        resume_id=resume.id,
        target_role=target_role,
        ats_score=result.ats_score,
        keyword_coverage=result.keyword_coverage,
        measurable_impact_ratio=result.measurable_impact_ratio,
        readability_score=result.readability_score,
        recruiter_signal_score=result.recruiter_signal_score,
    )
    db.add(scan)
    db.flush()

    for finding in result.findings:
        db.add(
            ScanFinding(
                scan_id=scan.id,
                category=finding.category,
                severity=finding.severity,
                message=finding.message,
                suggestion=finding.suggestion,
            )
        )

    db.commit()


def _enforce_scan_limit(db: Session, user: User) -> None:
    limits = usage_limits_snapshot(db, user.id)
    if limits.scans_remaining_today is not None and limits.scans_remaining_today <= 0:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Free plan daily scan limit reached.",
        )
