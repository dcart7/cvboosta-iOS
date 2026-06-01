# 05. ATS Backend + API Architecture

## Stack

- FastAPI
- PostgreSQL
- SQLAlchemy 2.0
- Google Gemini API
- PDF parser (`pypdf`)

## Service Boundaries

- `ats_engine.py`: deterministic scoring and finding generation
- `keyword_intelligence.py`: role keyword/expectation retrieval
- `gemini_service.py`: Gemini calls, retries, rate limit, fallback models
- `ai_orchestrator.py`: centralized AI feature orchestration
- `ai_response_parser.py`: strict JSON extraction for model outputs
- `token_usage_tracker.py`: token usage accounting
- `pdf_parser.py`: resume text extraction

## Scoring Model (MVP)

Final ATS score combines:

- Keyword coverage: 40%
- Measurable impact ratio: 25%
- Readability: 15%
- Action-verb strength: 10%
- Recruiter signal composite: 10%

## API Endpoints

- `POST /v1/resume/scan`
  - input: resume text + target role
  - output: ATS score, findings, rewrite suggestions
- `POST /v1/resume/scan-file`
  - input: multipart PDF + target role
  - output: ATS score, issues, keyword gaps, priority fixes
- `POST /v1/resume/rewrite`
  - input: bullet list + role
  - output: rewritten bullets
- `GET /v1/resume/ai-usage`
  - output: in-memory Gemini token usage totals
- `POST /v1/applications`
  - input: application record
  - output: persisted entity
- `GET /v1/applications/{user_id}`
  - output: user’s application list
- `GET /v1/analytics/summary/{user_id}`
  - output: applications total, 7-day velocity, interview rate, conversion rate

## Production Readiness Next

- Async job queue for large document analysis
- Request auth + rate limiting
- Structured logging + observability dashboards
- Offline keyword dataset sync from role intelligence CMS (600+ roles)
