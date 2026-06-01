from fastapi import APIRouter, File, Form, HTTPException, UploadFile

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

router = APIRouter()
ai_orchestrator = AIOrchestrator()


@router.post("/scan", response_model=ResumeScanResponse)
async def scan_resume(payload: ResumeScanRequest) -> ResumeScanResponse:
    deterministic_result = analyze_resume(payload.resume_text, payload.target_role)
    result = await ai_orchestrator.enhance_scan_result(
        resume_text=payload.resume_text,
        target_role=payload.target_role,
        result=deterministic_result,
    )

    return _to_scan_response(result)


@router.post("/scan-file", response_model=ResumeScanResponse)
async def scan_resume_file(file: UploadFile = File(...), target_role: str = Form(...)) -> ResumeScanResponse:
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
    )
    return _to_scan_response(result)


@router.post("/rewrite", response_model=RewriteResponse)
async def rewrite_resume_bullets(payload: RewriteRequest) -> RewriteResponse:
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
def ai_usage_snapshot() -> dict[str, dict[str, int]]:
    return token_usage_tracker.snapshot()
