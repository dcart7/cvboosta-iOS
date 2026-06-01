from datetime import datetime

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.models import Resume, ResumeScan, ScanFinding, User
from app.db.session import get_db
from app.schemas.resume import (
    ResumeScanRequest,
    ResumeScanResponse,
    RewriteRequest,
    RewriteResponse,
    ScanFindingDTO,
)
from app.services.ats_engine import ATSResult, analyze_resume
from app.services.ai_orchestrator import AIOrchestrator
from app.services.pdf_parser import parse_pdf_bytes
from app.services.token_usage_tracker import token_usage_tracker
from app.services.user_state import usage_limits_snapshot

router = APIRouter()
ai_orchestrator = AIOrchestrator()


@router.post("/scan", response_model=ResumeScanResponse)
async def scan_resume(
    payload: ResumeScanRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ResumeScanResponse:
    _enforce_scan_limit(db, user)
    deterministic_result = analyze_resume(payload.resume_text, payload.target_role)
    result = await ai_orchestrator.enhance_scan_result(
        resume_text=payload.resume_text,
        target_role=payload.target_role,
        result=deterministic_result,
    )

    _persist_scan(
        db=db,
        user=user,
        file_name=f"inline-resume-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}.txt",
        text_content=payload.resume_text,
        target_role=payload.target_role,
        result=result,
    )

    return _to_scan_response(result)


@router.post("/scan-file", response_model=ResumeScanResponse)
async def scan_resume_file(
    file: UploadFile = File(...),
    target_role: str = Form(...),
    job_description: str | None = Form(default=None),
    experience_level: str | None = Form(default=None),
    target_market: str | None = Form(default=None),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ResumeScanResponse:
    _enforce_scan_limit(db, user)
    if file.content_type not in {"application/pdf", "application/octet-stream"}:
        raise HTTPException(status_code=400, detail="Only PDF uploads are supported.")

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    try:
        extracted_text = parse_pdf_bytes(content)
    except Exception as error:
        raise HTTPException(status_code=400, detail="Invalid or unreadable PDF.") from error
    if len(extracted_text) < 120:
        raise HTTPException(
            status_code=400,
            detail="Could not extract enough text from PDF. Try an ATS-friendly exported PDF.",
        )

    deterministic_result = analyze_resume(extracted_text, target_role)
    result = await ai_orchestrator.enhance_scan_result(
        resume_text=extracted_text,
        target_role=target_role,
        result=deterministic_result,
        job_description=job_description,
        experience_level=experience_level,
        target_market=target_market,
    )

    _persist_scan(
        db=db,
        user=user,
        file_name=file.filename or "uploaded-resume.pdf",
        text_content=extracted_text,
        target_role=target_role,
        result=result,
    )

    return _to_scan_response(result)


@router.post("/rewrite", response_model=RewriteResponse)
async def rewrite_resume_bullets(
    payload: RewriteRequest,
    _: User = Depends(get_current_user),
) -> RewriteResponse:
    rewritten = await ai_orchestrator.rewrite_bullets(payload.target_role, payload.bullets)
    return RewriteResponse(rewritten_bullets=rewritten)


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


@router.get("/ai-usage")
def ai_usage_snapshot(_: User = Depends(get_current_user)) -> dict[str, dict[str, int]]:
    return token_usage_tracker.snapshot()


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
