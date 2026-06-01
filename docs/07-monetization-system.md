# 07. Monetization System (RevenueCat + Apple Subscriptions)

## Plan Structure

- Free
  - 3 scans/week
  - 5 rewrites/week
  - basic ATS findings
- Pro Monthly: `$12.99`
- Pro Annual: `$79.99`
- Lifetime: `$199`

## RevenueCat Configuration

- Entitlements:
  - `pro_access`
  - `lifetime_access`
- Offerings:
  - `default`
  - `winback`
  - `student_discount` (A/B test)

## Paywall Triggers

- Hard limit reached on scans/rewrites
- User hits ATS score plateau and asks for deeper insights
- Interview prep module locked action

## UX Requirements

- No dark patterns
- 1-screen value communication
- Show expected outcome delta:
  - "Pro users improve ATS score by +18 points median in 2 weeks"
- Include "Restore Purchases" and clear terms

## Events to Track

- paywall_viewed
- paywall_cta_tapped
- purchase_started
- purchase_completed
- trial_converted
- churn_detected
