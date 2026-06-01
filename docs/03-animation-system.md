# 03. Animation System

## Motion Principles

- Physical: object-like acceleration/deceleration
- Responsive: haptic + visual acknowledgement on critical taps
- Layered: parent surfaces move first, detail second
- Quiet by default: no ornamental motion loops

## Motion Tokens

- `BoostaMotion.snap`: rapid confirmations (buttons, toggles)
- `BoostaMotion.smooth`: card transitions, tab continuity
- `BoostaMotion.slowReveal`: onboarding and insight reveals

## Interaction Patterns

- Onboarding: full-screen page transitions + staggered text reveal
- Scanner: staged progress animation with midpoints (35% -> 78% -> 100%)
- Tailoring: rewrite result crossfade with light haptic impact
- Analytics: chart load with area fade + line trace

## Haptics Map

- Light impact: navigation and non-critical selection
- Medium/rigid impact: scan start and major workflow commits
- Success notification: analysis complete / subscription success

## Transition Guidelines

- Keep standard navigation pushes native for trust
- Use matched geometry only on high-value flows (scanner -> insights detail)
- Avoid parallax-heavy transitions to preserve calm feel
