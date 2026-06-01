# 13. Gemini-Only AI Architecture

## Provider policy

CVBoosta AI layer is standardized to Google Gemini only.
No OpenAI/Anthropic/Cohere/Mistral/local model dependencies are used.

## Backend AI stack

- `app/services/gemini_service.py`
  - Gemini API client
  - retry logic
  - fallback model routing inside Gemini ecosystem
  - in-memory rate limiter
  - timeout handling
- `app/services/ai_orchestrator.py`
  - central AI orchestration for scan enhancement and rewrites
- `app/services/prompt_templates/`
  - centralized prompt management
- `app/services/ai_response_parser.py`
  - strict JSON parsing and fallback extraction
- `app/services/token_usage_tracker.py`
  - per-model token usage tracking

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

- If Gemini is unavailable or fails, backend falls back to deterministic ATS analysis.
- Rewrite endpoint degrades to safe deterministic rewrite hints.
- iOS scanner stays stable and can use demo mode fallback if backend is unavailable.
