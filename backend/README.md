# CVBoosta Backend (FastAPI)

## Run locally

```bash
cd backend
cp .env.example .env
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Core endpoints

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/logout`
- `GET /auth/me`
- `POST /auth/refresh`
- `POST /auth/forgot-password`
- `POST /v1/resume/scan`
- `POST /v1/resume/scan-file` (multipart PDF upload)
- `POST /v1/resume/rewrite`
- `POST /v1/applications`
- `GET /v1/applications/me`
- `GET /v1/applications/{user_id}`
- `GET /v1/analytics/summary/me`
- `GET /v1/analytics/summary/{user_id}`
- `GET /health`

All protected endpoints require `Authorization: Bearer <access_token>`.

## Architecture

- FastAPI + SQLAlchemy + PostgreSQL
- Gemini-powered AI service layer (`gemini-2.5-flash` / `gemini-2.5-pro`)
- Role keyword intelligence dataset (seeded, expandable to 600+ roles)
- ATS scoring pipeline (keyword coverage, measurable impact, readability, recruiter signals)
