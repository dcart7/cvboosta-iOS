import re
from dataclasses import dataclass

from app.services.keyword_intelligence import get_role_expectations, get_role_keywords

ACTION_VERBS = {
    "built",
    "led",
    "optimized",
    "shipped",
    "designed",
    "scaled",
    "launched",
    "improved",
    "reduced",
    "increased",
    "automated",
}


@dataclass
class Finding:
    category: str
    severity: int
    message: str
    suggestion: str


@dataclass
class ATSResult:
    ats_score: int
    keyword_coverage: float
    measurable_impact_ratio: float
    readability_score: float
    recruiter_signal_score: float
    keyword_gaps: list[str]
    priority_fixes: list[str]
    weak_bullet_examples: list[str]
    rewrite_suggestions: list[str]
    findings: list[Finding]


def _tokenize(text: str) -> list[str]:
    return re.findall(r"[a-zA-Z0-9+/.-]+", text.lower())


def _score_keywords(tokens: list[str], keywords: list[str], text: str) -> float:
    if not keywords:
        return 0.0

    token_set = set(tokens)
    text_lower = text.lower()

    hits = 0
    for keyword in keywords:
        normalized = keyword.lower()
        if " " in normalized or "/" in normalized:
            if normalized in text_lower:
                hits += 1
        elif normalized in token_set:
            hits += 1

    return round(hits / len(keywords), 3)


def _score_measurable_impact(text: str) -> float:
    bullets = [line.strip() for line in text.splitlines() if line.strip().startswith(("-", "•"))]
    if not bullets:
        bullets = [line.strip() for line in text.splitlines() if line.strip()]

    if not bullets:
        return 0.0

    quantified = sum(1 for bullet in bullets if re.search(r"\d+%|\$\d+|\d+x|\d+\+", bullet))
    return round(quantified / len(bullets), 3)


def _score_action_verbs(tokens: list[str]) -> float:
    if not tokens:
        return 0.0

    action_hits = sum(1 for token in tokens if token in ACTION_VERBS)
    return min(action_hits / 12.0, 1.0)


def _score_readability(text: str) -> float:
    words = _tokenize(text)
    sentences = [chunk for chunk in re.split(r"[.!?]", text) if chunk.strip()]

    if not words or not sentences:
        return 0.0

    avg_words_per_sentence = len(words) / len(sentences)
    score = 1.0 - abs(avg_words_per_sentence - 18) / 30
    return round(max(min(score, 1.0), 0.0), 3)


def _extract_bullets(text: str) -> list[str]:
    bullets = [line.strip(" -•\t") for line in text.splitlines() if line.strip().startswith(("-", "•"))]
    if bullets:
        return bullets
    return [line.strip() for line in text.splitlines() if line.strip()]


def analyze_resume(resume_text: str, target_role: str) -> ATSResult:
    tokens = _tokenize(resume_text)
    token_set = set(tokens)
    role_keywords = get_role_keywords(target_role)
    role_expectations = get_role_expectations(target_role)

    keyword_coverage = _score_keywords(tokens, role_keywords, resume_text)
    measurable_impact_ratio = _score_measurable_impact(resume_text)
    action_verb_score = _score_action_verbs(tokens)
    readability_score = _score_readability(resume_text)

    recruiter_signal_score = round(
        (0.45 * keyword_coverage) + (0.3 * measurable_impact_ratio) + (0.25 * action_verb_score),
        3,
    )

    ats_score = int(
        (
            (keyword_coverage * 40)
            + (measurable_impact_ratio * 25)
            + (readability_score * 15)
            + (action_verb_score * 10)
            + (recruiter_signal_score * 10)
        )
    )

    findings: list[Finding] = []

    if keyword_coverage < 0.55:
        findings.append(
            Finding(
                category="keywords",
                severity=3,
                message="Role keyword coverage is below competitive threshold.",
                suggestion="Add missing terms from role requirements naturally in impact bullets.",
            )
        )

    if measurable_impact_ratio < 0.5:
        findings.append(
            Finding(
                category="impact",
                severity=3,
                message="Too few quantified achievements.",
                suggestion="Rewrite bullets with percentages, growth, cost savings, or volume metrics.",
            )
        )

    if readability_score < 0.6:
        findings.append(
            Finding(
                category="readability",
                severity=2,
                message="Sentence complexity may reduce ATS parsing confidence.",
                suggestion="Shorten long sentences and keep bullet structure uniform.",
            )
        )

    text_lower = resume_text.lower()
    missing_keywords = []
    for keyword in role_keywords:
        normalized = keyword.lower()
        if " " in normalized or "/" in normalized:
            if normalized not in text_lower:
                missing_keywords.append(keyword)
        elif normalized not in token_set:
            missing_keywords.append(keyword)

    top_missing = ", ".join(missing_keywords[:8]) if missing_keywords else "none"

    bullets = _extract_bullets(resume_text)
    weak_bullet_examples = []
    for bullet in bullets:
        lower = bullet.lower()
        has_metric = bool(re.search(r"\d+%|\$\d+|\d+x|\d+\+", bullet))
        starts_with_action = any(lower.startswith(f"{verb} ") for verb in ACTION_VERBS)
        if not has_metric or not starts_with_action:
            weak_bullet_examples.append(bullet)
        if len(weak_bullet_examples) == 3:
            break

    priority_fixes: list[str] = []
    for finding in sorted(findings, key=lambda item: item.severity, reverse=True):
        priority_fixes.append(finding.suggestion)

    if not priority_fixes:
        priority_fixes.append("Add one more role-aligned bullet with clear quantified outcomes.")

    rewrite_suggestions = [
        f"Add these missing role terms: {top_missing}",
        "Lead each bullet with a strong action verb and result.",
        f"Reflect recruiter expectations: {', '.join(role_expectations[:4])}",
    ]

    return ATSResult(
        ats_score=max(0, min(ats_score, 99)),
        keyword_coverage=keyword_coverage,
        measurable_impact_ratio=measurable_impact_ratio,
        readability_score=readability_score,
        recruiter_signal_score=recruiter_signal_score,
        keyword_gaps=missing_keywords[:12],
        priority_fixes=priority_fixes[:4],
        weak_bullet_examples=weak_bullet_examples,
        rewrite_suggestions=rewrite_suggestions,
        findings=findings,
    )
