# CVBoosta iOS Ecosystem (MVP Scaffold)

CVBoosta is a premium career operating system focused on ATS optimization, role-specific resume tailoring, interview conversion, and job search analytics.

This repository scaffold includes:

- SwiftUI app architecture with premium glass-style UI system
- Live Activities + Dynamic Island support
- WidgetKit lock-screen widgets
- FastAPI ATS backend engine with PostgreSQL models
- Role keyword intelligence seed dataset
- Monetization strategy with RevenueCat integration plan
- App Store ASO + launch strategy
- 3-5 week production MVP roadmap

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
│   │   ├── api/routes
│   │   ├── core
│   │   ├── db
│   │   ├── schemas
│   │   └── services
│   ├── data/roles
│   └── requirements.txt
├── docs
└── infra
```

## Deliverables Map

1. SwiftUI architecture: `docs/01-swiftui-architecture.md`
2. Design system: `docs/02-design-system.md`
3. Animation system: `docs/03-animation-system.md`
4. Liquid Glass components: `ios/CVBoostaApp/Core/DesignSystem/Components`
5. Live Activities: `ios/CVBoostaWidgetExtension/CVBoostaLiveActivity.swift`
6. Dynamic Island: `ios/CVBoostaWidgetExtension/CVBoostaLiveActivity.swift`
7. WidgetKit integration: `ios/CVBoostaWidgetExtension/CVBoostaWidgets.swift`
8. ATS backend engine: `backend/app/services/ats_engine.py`
9. API architecture: `docs/05-backend-api-architecture.md`
10. Database schema: `docs/06-database-schema.sql`
11. Folder structure: this README
12. Monetization system: `docs/07-monetization-system.md`
13. App Store strategy: `docs/08-app-store-strategy.md`
14. Launch strategy: `docs/09-launch-strategy.md`
15. MVP roadmap (3-5 weeks): `docs/10-mvp-roadmap-5-weeks.md`
16. App Store production checks: `docs/11-app-store-production-checks.md`
17. MVP vertical slice runbook: `docs/12-vertical-slice-runbook.md`
18. Gemini-only AI architecture: `docs/13-gemini-architecture.md`
19. Unified website+iOS auth setup: `docs/14-unified-auth-setup.md`

## Quick Start

Generate Xcode project (if using XcodeGen):

```bash
cd ios
xcodegen generate
```

```bash
cd infra
docker compose up
```

API health check:

```bash
curl http://localhost:8000/health
```
