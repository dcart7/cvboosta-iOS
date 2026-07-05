# CVBoosta iOS App

CVBoosta is a premium career operating system focused on ATS optimization, role-specific resume tailoring, interview conversion, and job search analytics.

This repository contains the native SwiftUI iOS app (iPhone + iPad), a local FastAPI backend harness for tracker/account flows, and supporting docs.

The app integrates directly with the production CVBoosta backend (one backend, one database). The `backend/` folder in this repo is a local development/reference implementation for auth, tracker sync, and smoke testing of the shared API contract.

## Folder Structure

```text
.
├── ios
│   ├── CVBoostaApp
│   │   ├── App
│   │   ├── Core
│   │   │   ├── Architecture
│   │   │   ├── DesignSystem
│   │   │   ├── Models
│   │   │   ├── Motion
│   │   │   └── Services
│   │   └── Features
│   │       ├── Analytics
│   │       ├── Home
│   │       ├── Onboarding
│   │       ├── Scanner
│   │       ├── Settings
│   │       ├── Tailoring
│   │       └── Tracker
│   └── CVBoostaWidgetExtension
├── backend
│   ├── app
│   ├── sql
│   └── tests
├── docs
```

## Deliverables Map

1. SwiftUI architecture: `docs/01-swiftui-architecture.md`
2. Design system: `docs/02-design-system.md`
3. Animation system: `docs/03-animation-system.md`
4. Liquid Glass components: `ios/CVBoostaApp/Core/DesignSystem/Components`
5. Live Activities: `ios/CVBoostaWidgetExtension/CVBoostaLiveActivity.swift`
6. Dynamic Island: `ios/CVBoostaWidgetExtension/CVBoostaLiveActivity.swift`
7. WidgetKit integration: `ios/CVBoostaWidgetExtension/CVBoostaWidgets.swift`
8. API architecture notes: `docs/05-backend-api-architecture.md`
9. Database schema reference (legacy): `docs/06-database-schema.sql`
10. Folder structure: this README
11. Monetization system notes: `docs/07-monetization-system.md`
12. MVP roadmap: `docs/10-mvp-roadmap-5-weeks.md`

## Quick Start

Generate Xcode project (if using XcodeGen):

```bash
cd ios
xcodegen generate
```

The backend base URL is configured via `API_BASE_URL` (Info.plist) and can be overridden at runtime via the `API_BASE_URL` environment variable for development/testing.

Run the local backend harness:

```bash
uvicorn backend.app.main:create_app --factory --reload
```
