from app.services.ats_engine import ATSResult
from app.services.gemini_service import GeminiService, GeminiServiceError, GeminiUnavailableError


class AIOrchestrator:
    def __init__(self, gemini_service: GeminiService | None = None) -> None:
        self.gemini_service = gemini_service or GeminiService()

    async def enhance_scan_result(
        self,
        resume_text: str,
        target_role: str,
        result: ATSResult,
        job_description: str | None = None,
        experience_level: str | None = None,
        target_market: str | None = None,
    ) -> ATSResult:
        try:
            payload = await self.gemini_service.ats_enhancement(
                target_role=target_role,
                resume_text=resume_text,
                deterministic_findings=[f"{f.category}: {f.suggestion}" for f in result.findings],
                job_description=job_description,
                experience_level=experience_level,
                target_market=target_market,
            )
        except (GeminiUnavailableError, GeminiServiceError):
            return result

        keyword_gaps = self._normalize_list(payload.get("keyword_gaps"), max_items=12, fallback=result.keyword_gaps)
        priority_fixes = self._normalize_list(
            payload.get("priority_fixes"), max_items=4, fallback=result.priority_fixes
        )
        weak_bullets = self._normalize_list(
            payload.get("weak_bullet_examples"), max_items=3, fallback=result.weak_bullet_examples
        )
        rewrite_suggestions = self._normalize_list(
            payload.get("rewrite_suggestions"), max_items=4, fallback=result.rewrite_suggestions
        )

        return ATSResult(
            ats_score=result.ats_score,
            keyword_coverage=result.keyword_coverage,
            measurable_impact_ratio=result.measurable_impact_ratio,
            readability_score=result.readability_score,
            recruiter_signal_score=result.recruiter_signal_score,
            keyword_gaps=keyword_gaps,
            priority_fixes=priority_fixes,
            weak_bullet_examples=weak_bullets,
            rewrite_suggestions=rewrite_suggestions,
            findings=result.findings,
        )

    async def rewrite_bullets(self, target_role: str, bullets: list[str]) -> list[str]:
        try:
            rewritten = await self.gemini_service.rewrite_bullets(target_role=target_role, bullets=bullets)
            return rewritten if rewritten else bullets
        except (GeminiUnavailableError, GeminiServiceError):
            return [
                f"[{target_role}] {bullet} -> Add quantified impact, role keywords, and recruiter-oriented outcomes."
                for bullet in bullets
            ]

    def _normalize_list(self, value: object, max_items: int, fallback: list[str]) -> list[str]:
        if not isinstance(value, list):
            return fallback[:max_items]

        cleaned: list[str] = []
        for item in value:
            text = str(item).strip()
            if text and text not in cleaned:
                cleaned.append(text)
            if len(cleaned) == max_items:
                break

        return cleaned if cleaned else fallback[:max_items]
