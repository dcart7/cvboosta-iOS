# 10. Production-Ready MVP Roadmap (3-5 Weeks)

## Week 1 (Foundation)

- Ship app shell, design system, navigation, SwiftData models
- Implement onboarding + home + scanner UI
- Stand up FastAPI + Postgres + ATS scoring endpoint
- Define analytics events and logging schema

## Week 2 (Core Intelligence)

- Connect scanner to backend
- Implement rewrite endpoint and role keyword dataset integration
- Build tracker CRUD and analytics summary endpoint
- Add file import + PDF parse path

## Week 3 (Apple Ecosystem + Monetization)

- Add ActivityKit live activities + Dynamic Island
- Add WidgetKit lock-screen/home widgets
- Integrate Sign in with Apple
- Integrate RevenueCat offerings/paywall

## Week 4 (Polish + QA)

- Motion/haptics tuning across key flows
- Improve error states, retries, offline handling
- Add App Store creative assets and onboarding copy tests
- Run TestFlight with 100 beta users

## Week 5 (Launch Buffer, optional but recommended)

- Fix TestFlight issues
- Tune paywall and onboarding conversion
- Improve ATS scoring heuristics from user data
- Submit App Store release and ship press/creator campaign

## Launch Gate Checklist

- Crash-free rate > 99.5%
- ATS scan p95 response < 2.5s
- Rewrite p95 response < 4.0s
- Trial start conversion > 8%
- Day-7 retention > 22%
