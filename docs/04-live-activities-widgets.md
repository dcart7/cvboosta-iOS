# 04. Live Activities + Widgets

## Live Activities States

`CVBoostaActivityAttributes.ContentState` supports:

- `atsOptimization`
- `tailoring`
- `interviewCountdown`
- `applicationStatus`
- `dailyStreak`

Tracked fields:

- `title`
- `detail`
- `progress`
- `etaText`

## Dynamic Island

- Compact Leading: CVBoosta symbol
- Compact Trailing: progress percentage
- Minimal: trend icon
- Expanded:
  - Leading: brand/status
  - Trailing: % complete
  - Center: activity summary
  - Bottom: progress bar

## Lock Screen Widgets Included

- ATS score widget
- Daily applications widget
- Job search streak widget
- Interview countdown widget

## Suggested Activity Triggers

- Scan started -> ATS optimization activity
- Rewrite batch started -> tailoring activity
- Interview date set -> countdown activity
- Application state changes -> status activity
- Daily action complete -> streak activity
