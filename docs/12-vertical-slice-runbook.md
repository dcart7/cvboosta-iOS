# 12. MVP Vertical Slice Runbook

## 1) Backend

The iOS app uses the production CVBoosta backend (Cloud Run). No backend is run from this repo.

Health check (replace base URL if overridden):

```bash
curl https://cvboosta-backend-615826584976.europe-west3.run.app/health
```

## 2) iOS project generation

If `xcodegen` is missing:

```bash
brew install xcodegen
```

```bash
cd ios
xcodegen generate
```

## 3) Xcode build/run

1. Open generated `CVBoosta.xcodeproj` in Xcode.
2. Select `CVBoostaApp` scheme.
3. Set signing team and replace bundle IDs if needed.
4. Run on iOS 17+ simulator/device.
5. In Scanner tab:
   - Upload a resume PDF
   - Enter a target role (job description is optional)
   - Run analysis and review results

Run iOS unit tests:

```bash
xcodebuild test -project CVBoosta.xcodeproj -scheme CVBoostaApp -destination 'platform=iOS Simulator,name=iPhone 16'
```

## 4) Smoke test flow

- Login/register
- Run one scan + confirm result renders
- Open Tailoring and confirm side-by-side original vs optimized on iPad
- Verify `/billing/status` reflects the website subscription state for the same user

## 5) Known limitations (current slice)

- Payments and plan management live on the website (Stripe).
- APNs device-token sync requires a backend endpoint (disabled by default in iOS unless `APNS_REGISTER_PATH` is configured).

## 6) If Xcode Preview does not open

1. Ensure full Xcode is selected (not only Command Line Tools):

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

2. In Xcode:
   - open `CVBoosta.xcodeproj`
   - select `CVBoostaApp` scheme (not widget extension)
   - choose an iOS 17+ preview device
3. Clean preview cache:
   - `Product -> Clean Build Folder`
   - delete `~/Library/Developer/Xcode/DerivedData`
4. Reopen canvas and press `Resume`.
