# 14. Unified Auth Setup (Website + iOS)

## Goal

Use one backend and one database for both website and iOS:

`iOS app -> CVBoosta API -> existing website tables`

No iOS-only users table is created.

## Backend Setup

1. Install dependencies:

```bash
cd backend
pip install -r requirements.txt
```

2. Configure environment:

```bash
cp .env.example .env
```

Required auth values in `.env`:

- `JWT_SECRET_KEY` (set to a strong 32+ char secret)
- `JWT_ALGORITHM` (default: `HS256`)
- `ACCESS_TOKEN_EXPIRE_MINUTES` (default: `15`)
- `REFRESH_TOKEN_EXPIRE_DAYS` (default: `30`)
- `PASSWORD_RESET_TOKEN_EXPIRE_MINUTES` (default: `30`)

3. Start API:

```bash
uvicorn app.main:app --reload
```

## Auth Endpoints

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/logout`
- `GET /auth/me`
- `POST /auth/refresh`
- `POST /auth/forgot-password`

Protected endpoints require:

`Authorization: Bearer <access_token>`

## Shared User State Returned by `/auth/me`

- profile (`user`)
- subscription status (`subscription`)
- usage limits (`usage_limits`)
- saved resumes (`saved_resumes`)
- scan history (`scan_history`)
- applications/account data (`applications`)

## iOS Integration

Implemented components:

- `Core/Services/AuthService.swift`
- `Core/Services/AuthViewModel.swift`
- `Core/Services/KeychainService.swift`
- `Core/Services/AuthenticatedAPIClient.swift`
- `Features/Auth/LoginView.swift`
- `Features/Auth/RegisterView.swift`
- `Features/Auth/ForgotPasswordView.swift`

Behavior:

- Tokens are stored in Keychain only.
- Protected requests send Bearer token.
- On `401`, client attempts refresh and retries once.
- If refresh fails, session is cleared and user is logged out.

## Validate

Backend tests:

```bash
cd backend
PYTHONPATH=. pytest -q
```

iOS build:

```bash
cd ios
xcodegen generate
xcodebuild -project CVBoosta.xcodeproj -scheme CVBoostaApp -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```
