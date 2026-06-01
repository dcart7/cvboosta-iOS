# 02. Complete Design System

## Visual Direction

- Personality: calm, premium, intelligent, reassuring
- Composition: large type + high whitespace + layered glass surfaces
- Style influences: Wallet-level material depth, Arc-level flow, Notion-level clarity

## Tokens

- Color tokens: `BoostaColor`
- Typography tokens: `BoostaType`
- Spacing/radius tokens: `BoostaSpace`, `BoostaRadius`
- Motion tokens: `BoostaMotion`

## Liquid Glass UI Rules

- Card surface: `ultraThinMaterial`
- Card stroke: white alpha border (`0.42`) to create refractive edges
- Shadow: soft, downward, low contrast
- Depth hierarchy:
  - Level 1: page gradient
  - Level 2: base glass surfaces
  - Level 3: interactive pills/buttons
  - Level 4: modal or full-screen overlays

## Reusable Components

- `GlassCard`: primary surface container
- `MetricPill`: compact KPI display
- `StaggeredReveal`: entrance hierarchy

## Typography Hierarchy

- Hero: high-emotion onboarding and key score moments
- Title/Section: module framing and card headings
- Body/Caption: tactical guidance and dense content

## UX Principles

- Never overload: max 3 high-salience actions per screen
- Every metric needs meaning: always pair KPI with next action
- Bias toward forward momentum: CTA language should feel directional
