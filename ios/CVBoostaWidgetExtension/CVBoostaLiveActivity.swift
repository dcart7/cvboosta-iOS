import ActivityKit
import SwiftUI
import WidgetKit

struct CVBoostaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CVBoostaActivityAttributes.self) { context in
            LiveActivityLockScreenView(context: context)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white.opacity(0.96))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ActivityBadge(text: badgeText(for: context.state), accent: accent(for: context.state.mode))
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(state: context.state)
                }
            } compactLeading: {
                CompactLeadingView(state: context.state)
            } compactTrailing: {
                Text(compactText(for: context.state))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))
                    .lineLimit(1)
            } minimal: {
                Image(systemName: iconName(for: context.state.mode))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent(for: context.state.mode))
            }
            .widgetURL(URL(string: "cvboosta://live"))
            .keylineTint(accent(for: context.state.mode))
        }
    }

    private func accent(for mode: CVBoostaActivityAttributes.ActivityMode) -> Color {
        switch mode {
        case .dailyStreak:
            return Color(red: 0.98, green: 0.67, blue: 0.41)
        default:
            return Color(red: 0.39, green: 0.88, blue: 1.0)
        }
    }

    private func iconName(for mode: CVBoostaActivityAttributes.ActivityMode) -> String {
        switch mode {
        case .atsOptimization, .tailoring:
            return "sparkles"
        case .dailyStreak:
            return "flame.fill"
        case .applicationStatus:
            return "briefcase.fill"
        case .interviewCountdown:
            return "calendar.badge.clock"
        case .postInterviewReflection:
            return "bubble.left.and.text.bubble.right.fill"
        }
    }

    private func badgeText(for state: CVBoostaActivityAttributes.ContentState) -> String {
        if let badge = state.badgeText?.trimmed, !badge.isEmpty {
            return badge
        }

        switch state.mode {
        case .dailyStreak, .interviewCountdown, .postInterviewReflection:
            return state.etaText.trimmed.isEmpty ? "Live" : state.etaText
        default:
            return "\(Int(progressValue(for: state) * 100))%"
        }
    }

    private func compactText(for state: CVBoostaActivityAttributes.ContentState) -> String {
        if let compact = state.compactTrailingText?.trimmed, !compact.isEmpty {
            return compact
        }

        if let badge = state.badgeText?.trimmed, !badge.isEmpty {
            return badge
        }

        switch state.mode {
        case .dailyStreak, .interviewCountdown, .postInterviewReflection:
            return state.etaText.trimmed.isEmpty ? "Live" : state.etaText
        default:
            return "\(Int(progressValue(for: state) * 100))%"
        }
    }

    private func progressValue(for state: CVBoostaActivityAttributes.ContentState) -> Double {
        min(max(state.progress, 0), 1)
    }

    private func eyebrowText(for mode: CVBoostaActivityAttributes.ActivityMode) -> String {
        switch mode {
        case .atsOptimization, .tailoring:
            return "AI ANALYSIS"
        case .dailyStreak:
            return "MOMENTUM"
        case .applicationStatus:
            return "PIPELINE"
        case .interviewCountdown:
            return "INTERVIEW"
        case .postInterviewReflection:
            return "REFLECTION"
        }
    }
}

private struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<CVBoostaActivityAttributes>

    var body: some View {
        let state = context.state
        let accent = accent(for: state.mode)

        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.92),
                            Color(red: 0.03, green: 0.06, blue: 0.12).opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.16),
                            .clear,
                            .white.opacity(0.02)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(accent.opacity(0.14), lineWidth: 1)
                .blur(radius: 1.2)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.18))
                            Circle()
                                .strokeBorder(accent.opacity(0.34), lineWidth: 1)
                            Image(systemName: iconName(for: state.mode))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        .frame(width: 30, height: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(eyebrowText(for: state.mode))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .tracking(1.1)
                                .foregroundStyle(.white.opacity(0.52))
                            Text(state.title)
                                .font(.system(size: 21, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.98))
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 12)

                    ActivityBadge(text: badgeText(for: state), accent: accent)
                }

                Text(state.detail)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)

                PremiumProgressBar(progress: progressValue(for: state), accent: accent)

                if !state.etaText.trimmed.isEmpty {
                    Text(state.etaText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .padding(.vertical, 6)
    }

    private func accent(for mode: CVBoostaActivityAttributes.ActivityMode) -> Color {
        switch mode {
        case .dailyStreak:
            return Color(red: 0.98, green: 0.67, blue: 0.41)
        default:
            return Color(red: 0.39, green: 0.88, blue: 1.0)
        }
    }

    private func iconName(for mode: CVBoostaActivityAttributes.ActivityMode) -> String {
        switch mode {
        case .atsOptimization, .tailoring:
            return "sparkles"
        case .dailyStreak:
            return "flame.fill"
        case .applicationStatus:
            return "briefcase.fill"
        case .interviewCountdown:
            return "calendar.badge.clock"
        case .postInterviewReflection:
            return "bubble.left.and.text.bubble.right.fill"
        }
    }

    private func badgeText(for state: CVBoostaActivityAttributes.ContentState) -> String {
        if let badge = state.badgeText?.trimmed, !badge.isEmpty {
            return badge
        }

        switch state.mode {
        case .dailyStreak, .interviewCountdown, .postInterviewReflection:
            return state.etaText.trimmed.isEmpty ? "Live" : state.etaText
        default:
            return "\(Int(progressValue(for: state) * 100))%"
        }
    }

    private func progressValue(for state: CVBoostaActivityAttributes.ContentState) -> Double {
        min(max(state.progress, 0), 1)
    }

    private func eyebrowText(for mode: CVBoostaActivityAttributes.ActivityMode) -> String {
        switch mode {
        case .atsOptimization, .tailoring:
            return "AI ANALYSIS"
        case .dailyStreak:
            return "MOMENTUM"
        case .applicationStatus:
            return "PIPELINE"
        case .interviewCountdown:
            return "INTERVIEW"
        case .postInterviewReflection:
            return "REFLECTION"
        }
    }
}

private struct ExpandedLeadingView: View {
    let state: CVBoostaActivityAttributes.ContentState

    var body: some View {
        let accent = accent(for: state.mode)

        HStack(spacing: 8) {
            Image(systemName: iconName(for: state.mode))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)

            if state.mode == .atsOptimization || state.mode == .tailoring {
                Text("ATS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }

    private func accent(for mode: CVBoostaActivityAttributes.ActivityMode) -> Color {
        switch mode {
        case .dailyStreak:
            return Color(red: 0.98, green: 0.67, blue: 0.41)
        default:
            return Color(red: 0.39, green: 0.88, blue: 1.0)
        }
    }

    private func iconName(for mode: CVBoostaActivityAttributes.ActivityMode) -> String {
        switch mode {
        case .atsOptimization, .tailoring:
            return "sparkles"
        case .dailyStreak:
            return "flame.fill"
        case .applicationStatus:
            return "briefcase.fill"
        case .interviewCountdown:
            return "calendar.badge.clock"
        case .postInterviewReflection:
            return "bubble.left.and.text.bubble.right.fill"
        }
    }
}

private struct ExpandedCenterView: View {
    let state: CVBoostaActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(state.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.98))
                .lineLimit(1)

            Text(state.detail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
    }
}

private struct ExpandedBottomView: View {
    let state: CVBoostaActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PremiumProgressBar(progress: progressValue(for: state), accent: accent(for: state.mode))
                .frame(height: 4)

            if !state.etaText.trimmed.isEmpty {
                Text(state.etaText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(1)
            }
        }
        .padding(.top, 4)
    }

    private func accent(for mode: CVBoostaActivityAttributes.ActivityMode) -> Color {
        switch mode {
        case .dailyStreak:
            return Color(red: 0.98, green: 0.67, blue: 0.41)
        default:
            return Color(red: 0.39, green: 0.88, blue: 1.0)
        }
    }

    private func progressValue(for state: CVBoostaActivityAttributes.ContentState) -> Double {
        min(max(state.progress, 0), 1)
    }
}

private struct CompactLeadingView: View {
    let state: CVBoostaActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName(for: state.mode))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent(for: state.mode))

            if state.mode == .atsOptimization || state.mode == .tailoring {
                Text("ATS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
            }
        }
    }

    private func accent(for mode: CVBoostaActivityAttributes.ActivityMode) -> Color {
        switch mode {
        case .dailyStreak:
            return Color(red: 0.98, green: 0.67, blue: 0.41)
        default:
            return Color(red: 0.39, green: 0.88, blue: 1.0)
        }
    }

    private func iconName(for mode: CVBoostaActivityAttributes.ActivityMode) -> String {
        switch mode {
        case .atsOptimization, .tailoring:
            return "sparkles"
        case .dailyStreak:
            return "flame.fill"
        case .applicationStatus:
            return "briefcase.fill"
        case .interviewCountdown:
            return "calendar.badge.clock"
        case .postInterviewReflection:
            return "bubble.left.and.text.bubble.right.fill"
        }
    }
}

private struct PremiumProgressBar: View {
    let progress: Double
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.08))

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.78),
                                accent.opacity(0.42)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(proxy.size.width * clamped, clamped > 0 ? 24 : 0))
                    .overlay(alignment: .trailing) {
                        Circle()
                            .fill(accent.opacity(0.9))
                            .frame(width: 6, height: 6)
                            .blur(radius: 0.2)
                            .opacity(clamped > 0.03 ? 1 : 0)
                    }
            }
        }
        .frame(height: 4)
    }
}

private struct ActivityBadge: View {
    let text: String
    let accent: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.96))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(accent.opacity(0.24), lineWidth: 1)
            )
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
