# 13. Gemini-Only AI Architecture

## Provider policy

CVBoosta AI layer is standardized to Google Gemini only.
No OpenAI/Anthropic/Cohere/Mistral/local model dependencies are used.

## Backend AI stack

Backend implementation lives in the production backend repo (not in this iOS repo).

Conceptually, the backend AI layer typically includes:

- Gemini API client + retries/timeouts
- Orchestration layer (scan, optimize, cover letter)
- Prompt/template management
- Strict response parsing
- Usage/rate limiting and logging

## Models strategy

- Fast operations: `GEMINI_MODEL_FAST` (default `gemini-2.5-flash`)
- Deep rewrite operations: `GEMINI_MODEL_PRO` (default `gemini-2.5-pro`)

## Environment variables

- `GEMINI_API_KEY`
- `GEMINI_MODEL_FAST`
- `GEMINI_MODEL_PRO`
- `GEMINI_TIMEOUT_SECONDS`
- `GEMINI_MAX_RETRIES`
- `GEMINI_REQUESTS_PER_MINUTE`

## Failure handling

- iOS app surfaces backend errors (network/auth) and prompts the user to retry.
- Backend should return structured errors (`{"detail": "..."}`) for client display.
