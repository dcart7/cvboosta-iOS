# 12. MVP Vertical Slice Runbook

## 1) Backend setup

```bash
cd backend
cp .env.example .env
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

## 2) Backend tests

Because the workspace path includes `[slug]`, run tests from a bracket-free path:

```bash
rm -rf /private/tmp/cvboosta_test
mkdir -p /private/tmp/cvboosta_test
rsync -a backend/ /private/tmp/cvboosta_test/backend/
cd /private/tmp/cvboosta_test/backend
PYTHONPATH=. pytest -q
```

## 3) iOS project generation

If `xcodegen` is missing:

```bash
brew install xcodegen
```

```bash
cd ios
xcodegen generate
```

## 4) Xcode build/run

1. Open generated `CVBoosta.xcodeproj` in Xcode.
2. Select `CVBoostaApp` scheme.
3. Set signing team and replace bundle IDs if needed.
4. Run on iOS 17+ simulator/device.
5. In Scanner tab:
   - Tap `Select PDF and Scan`
   - Choose a PDF from Files
   - Wait for scan progress + Live Activity
   - Review ATS results in `ATS Results` screen

Run iOS unit tests:

```bash
xcodebuild test -project CVBoosta.xcodeproj -scheme CVBoostaApp -destination 'platform=iOS Simulator,name=iPhone 16'
```

## 5) Smoke test flow

- Production path:
  - Backend running
  - Upload valid resume PDF
  - Confirm result shows real score and findings
- Demo fallback path:
  - Stop backend
  - Upload PDF again
  - Confirm result shows `DEMO` badge and mock analysis
- Free gate:
  - Scan once as free user
  - Second scan same day should show limit reached
- Premium placeholder:
  - Open paywall and tap `Start Free Trial`
  - Confirm unlimited scans

## 6) Known limitations (current slice)

- RevenueCat is placeholder logic only (no SDK wiring yet).
- App icon set is placeholder and must be replaced before release.
- Local ATS HTTP exceptions are present for localhost development.
- PDF extraction quality depends on source PDF text layer.
- iOS unit tests are added but not executed in this environment.

## 7) If Xcode Preview does not open

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
