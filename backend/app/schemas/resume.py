from pydantic import BaseModel, Field


class ResumeScanRequest(BaseModel):
    resume_text: str = Field(min_length=120)
    target_role: str = Field(min_length=2, max_length=120)


class ScanFindingDTO(BaseModel):
    category: str
    severity: int
    message: str
    suggestion: str


class ResumeScanResponse(BaseModel):
    ats_score: int
    keyword_coverage: float
    measurable_impact_ratio: float
    readability_score: float
    recruiter_signal_score: float
    keyword_gaps: list[str]
    priority_fixes: list[str]
    weak_bullet_examples: list[str]
    rewrite_suggestions: list[str]
    findings: list[ScanFindingDTO]


class RewriteRequest(BaseModel):
    target_role: str
    bullets: list[str]


class RewriteResponse(BaseModel):
    rewritten_bullets: list[str]
