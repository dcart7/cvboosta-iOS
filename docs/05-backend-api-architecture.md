# 05. ATS Backend + API Architecture

## Scope

The production backend is hosted separately (Google Cloud Run) and is shared by both the website and the iOS app.

The canonical API surface is documented via OpenAPI on the production backend:

- `GET /openapi.json`
- `GET /docs`

## API Endpoints

Public:

- `GET /health`
- `POST /analyze/upload` (parse uploaded CV PDF)
- `POST /analyze/cv` (analyze CV text)
- `POST /analyze/job` (analyze job text)
- `POST /analyze/keywords` (extract job keywords)
- `POST /analyze/match` (CV↔job keyword match)
- `GET /demo/optimize` (demo payload)

Authenticated (Bearer token):

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`
- `POST /auth/logout`
- `POST /auth/forgot-password`
- `GET /billing/status`
- `POST /optimize`
- `POST /optimize/cover-letter`
- `GET /history`
- `GET /history/{item_id}`
- `GET /tracker`
- `POST /tracker/applications`
- `PATCH /tracker/applications/{application_id}`
- `DELETE /tracker/applications/{application_id}`
- `POST /tracker/folders`
- `PATCH /tracker/folders/{folder_id}`
- `DELETE /tracker/folders/{folder_id}`

## Production Readiness Next

- Async job queue for large document analysis
- Request auth + rate limiting
- Structured logging + observability dashboards
- Stable response schemas for endpoints that currently return free-form JSON (e.g. billing status)
