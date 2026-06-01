# 01. Full SwiftUI Architecture

## App Architecture

- Pattern: `Modular MVVM + Services + SwiftData`
- Navigation: `NavigationStack + TabView` command-center shell
- Persistence: `SwiftData` with CloudKit sync-ready configuration
- Sync model: local-first, API reconcile in background
- State split:
  - Global: auth, subscription, user context
  - Feature: scanner, tailoring, tracker, analytics
  - Ephemeral: animations, transient UI hints

## Module Design

### App
- `CVBoostaApp.swift`
- sets shared model container
- wires root tabs and app-level services

### Core
- `Architecture`: routes, navigation enums
- `DesignSystem`: tokens + reusable liquid-glass components
- `Motion`: spring curves, staggered reveal modifier
- `Services`: API client, haptics, auth, sync abstractions
- `Models`: `ResumeProfile`, `ApplicationRecord`, `ATSInsight`

### Features
- `Onboarding`: emotional narrative + positioning education
- `Home`: career command center
- `Scanner`: ATS scoring + weaknesses
- `Tailoring`: role-specific rewriting workflow
- `Analytics`: ATS trend and conversion views
- `Tracker`: application lifecycle management
- `Settings/Paywall`: monetization entry

## Apple Ecosystem Integrations (Implementation Checklist)

- Apple Sign In: `AuthenticationServices` (`AuthService`)
- iCloud Sync: SwiftData + CloudKit container
- Handoff: `NSUserActivity` on active modules (`scan`, `interview prep`)
- Share Sheet: export resume PDF and share from scanner result
- Spotlight Search: index scanned resumes + target roles via Core Spotlight
- Siri Suggestions: donate intents for "Run ATS Scan", "Prep Interview"
- Dynamic Island + Live Activities: ActivityKit extension included
- Widgets: lock/home widgets included
- Universal Links: map `cvboosta.com/roles/:slug` to tailoring screen
- Apple Pay: in-app subscriptions via StoreKit + RevenueCat abstraction
- Face ID: local unlock of exported docs / private analytics areas
- Native PDF support: `PDFKit` + file importer
- Drag & Drop: resume upload into scanner and tailoring surfaces

## Scalability Strategy

- Add modules under `Features/*` without touching global shell
- Keep API contracts versioned (`/v1`)
- Introduce background job queue for heavy parsing/rewrite tasks
- Add experimentation flags from remote config for onboarding/paywall tuning
