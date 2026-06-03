# 14. Unified Auth Setup (Website + iOS)

## Goal

Use one backend and one database for both website and iOS:

`iOS app -> CVBoosta production API -> existing CVBoosta tables`

No iOS-only users table is created.

## Production Backend

The production backend is hosted separately (Google Cloud Run) and is not part of this repo.

## Auth Endpoints

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/logout`
- `GET /auth/me`
- `POST /auth/forgot-password`

Protected endpoints require:

`Authorization: Bearer <access_token>`

## Subscription + History Endpoints

- `GET /billing/status` (subscription status)
- `GET /history` (user optimization history)
- `GET /history/{item_id}` (history details)

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
- On `401`, session is cleared and user is logged out.

## Validate

iOS build:

```bash
cd ios
xcodegen generate
xcodebuild -project CVBoosta.xcodeproj -scheme CVBoostaApp -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```
