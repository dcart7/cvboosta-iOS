# 11. App Store Production Checks

## Info.plist keys added

In `ios/CVBoostaApp/Info.plist`:

- `API_BASE_URL` (environment base URL)
- `DEMO_FALLBACK_ENABLED` (demo fallback flag)
- `APP_BUNDLE_ID_PLACEHOLDER`
- `NSFaceIDUsageDescription`
- `NSAppTransportSecurity`
  - `NSAllowsLocalNetworking`
  - Localhost/127.0.0.1 exceptions for dev

## Bundle ID placeholders

- App: `com.cvboosta.app`
- Widget: `com.cvboosta.widgets`
- Tests: `com.cvboosta.app.tests`

Replace with your real team bundle IDs before submission.

## Network security notes

- Local networking exceptions are for development.
- For App Store production, use HTTPS API endpoints and remove insecure HTTP exceptions.

## App icon placeholder

- Placeholder asset catalog created at:
  - `ios/CVBoostaApp/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Replace with full icon set sizes before archive.

## Build settings notes

In `ios/project.yml`:

- `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`
- `SWIFT_VERSION: 5.10`
- Bundle identifier placeholders
- Test target added

## Pre-submission checklist

1. Set production `API_BASE_URL`.
2. Disable or remove demo fallback in release.
3. Replace app icon placeholder with full icon set.
4. Confirm no local ATS exceptions remain unless justified.
5. Configure Apple Sign In capability and entitlements.
