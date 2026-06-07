import ActivityKit
import Foundation

@MainActor
@available(iOS 16.1, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentATSActivity: Activity<CVBoostaActivityAttributes>?
    private var currentSupportActivity: Activity<CVBoostaActivityAttributes>?

    private init() {}

    func startATSOptimization(title: String, detail: String) async {
        let attributes = CVBoostaActivityAttributes(activityName: "ATS Optimization")
        let state = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: title,
            detail: detail,
            progress: 0.05,
            etaText: "Preparing"
        )

        do {
            if let currentATSActivity {
                await currentATSActivity.end(nil, dismissalPolicy: .immediate)
            }
            currentATSActivity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: Date().addingTimeInterval(60 * 10)))
        } catch {
            print("Failed to start live activity: \(error)")
        }
    }

    func update(progress: Double, detail: String, etaText: String) async {
        guard let activity = currentATSActivity else { return }

        let newState = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS Optimization",
            detail: detail,
            progress: progress,
            etaText: etaText
        )

        await activity.update(.init(state: newState, staleDate: nil))
    }

    func markATSBackgrounded(progress: Double, detail: String) async {
        guard let activity = currentATSActivity else { return }

        let newState = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS Scan running",
            detail: detail,
            progress: progress,
            etaText: "Continuing in background"
        )

        await activity.update(.init(state: newState, staleDate: Date().addingTimeInterval(60 * 15)))
    }

    func end() async {
        guard let activity = currentATSActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        currentATSActivity = nil
    }

    func complete(finalScore: Int) async {
        guard let activity = currentATSActivity else { return }

        let completed = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS Scan Complete",
            detail: "Final score: \(finalScore)",
            progress: 1.0,
            etaText: ""
        )

        await activity.update(.init(state: completed, staleDate: nil))
        await activity.end(nil, dismissalPolicy: .default)
        currentATSActivity = nil
    }

    func celebrateDailyStreak(dayCount: Int, detail: String) async {
        let attributes = CVBoostaActivityAttributes(activityName: "Career Streak")
        let state = CVBoostaActivityAttributes.ContentState(
            mode: .dailyStreak,
            title: dayCount == 0 ? "Momentum started" : "Streak protected 🔥",
            detail: detail,
            progress: min(max(Double(dayCount) / 30.0, 0.08), 1),
            etaText: dayCount == 0 ? "Day 1" : "\(dayCount) days"
        )

        do {
            let activity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: Date().addingTimeInterval(60 * 5)))
            await activity.end(nil, dismissalPolicy: .default)
        } catch {
            print("Failed to celebrate streak activity: \(error)")
        }
    }

    func showStreakProtection(dayCount: Int, detail: String) async {
        let progress = min(max(Double(dayCount) / 30.0, 0.08), 1)
        let state = CVBoostaActivityAttributes.ContentState(
            mode: .dailyStreak,
            title: "Protect your streak",
            detail: detail,
            progress: progress,
            etaText: dayCount == 0 ? "One action" : "\(dayCount) days alive"
        )

        await upsertSupportActivity(
            attributesName: "Streak Protection",
            state: state,
            staleDate: Date().addingTimeInterval(60 * 90),
            priority: .dailyStreak
        )
    }

    func showInterviewCountdown(company: String, role: String, interviewAt: Date) async {
        let remaining = interviewAt.timeIntervalSinceNow
        guard remaining > 0, remaining <= 60 * 60 * 3 else {
            if currentSupportMode == .interviewCountdown {
                await clearSupportActivity()
            }
            return
        }

        let progress = max(0, min(1, 1 - (remaining / (60 * 60 * 3))))
        let state = CVBoostaActivityAttributes.ContentState(
            mode: .interviewCountdown,
            title: company,
            detail: role,
            progress: progress,
            etaText: interviewAt.formatted(date: .omitted, time: .shortened)
        )

        await upsertSupportActivity(
            attributesName: "Interview Countdown",
            state: state,
            staleDate: interviewAt.addingTimeInterval(60 * 30),
            priority: .interviewCountdown
        )
    }

    func showPostInterviewReflection(company: String, role: String) async {
        let state = CVBoostaActivityAttributes.ContentState(
            mode: .postInterviewReflection,
            title: "Log how it went",
            detail: "\(company) • \(role)",
            progress: 1,
            etaText: "While it’s fresh"
        )

        await upsertSupportActivity(
            attributesName: "Interview Reflection",
            state: state,
            staleDate: Date().addingTimeInterval(60 * 90),
            priority: .postInterviewReflection
        )
    }

    func clearPostInterviewReflection() async {
        guard currentSupportMode == .postInterviewReflection else { return }
        await clearSupportActivity()
    }

    func clearInterviewCountdown() async {
        guard currentSupportMode == .interviewCountdown else { return }
        await clearSupportActivity()
    }

    func clearStreakProtection() async {
        guard currentSupportMode == .dailyStreak else { return }
        await clearSupportActivity()
    }

    func fail() async {
        guard let activity = currentATSActivity else { return }

        let failed = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS Scan Failed",
            detail: "Please try again",
            progress: 0.0,
            etaText: ""
        )

        await activity.update(.init(state: failed, staleDate: nil))
        await activity.end(nil, dismissalPolicy: .default)
        currentATSActivity = nil
    }

    private var currentSupportMode: CVBoostaActivityAttributes.ActivityMode? {
        currentSupportActivity?.content.state.mode
    }

    private func upsertSupportActivity(
        attributesName: String,
        state: CVBoostaActivityAttributes.ContentState,
        staleDate: Date?,
        priority: SupportPriority
    ) async {
        if let currentSupportMode {
            let currentPriority = SupportPriority(mode: currentSupportMode)
            guard priority.rawValue >= currentPriority.rawValue || currentSupportMode == state.mode else {
                return
            }
        }

        if let activity = currentSupportActivity, activity.content.state.mode == state.mode {
            await activity.update(.init(state: state, staleDate: staleDate))
            return
        }

        if let activity = currentSupportActivity {
            await activity.end(nil, dismissalPolicy: .default)
            currentSupportActivity = nil
        }

        do {
            let attributes = CVBoostaActivityAttributes(activityName: attributesName)
            currentSupportActivity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: staleDate))
        } catch {
            print("Failed to start support live activity: \(error)")
        }
    }

    private func clearSupportActivity() async {
        guard let activity = currentSupportActivity else { return }
        await activity.end(nil, dismissalPolicy: .default)
        currentSupportActivity = nil
    }
}

@available(iOS 16.1, *)
private enum SupportPriority: Int {
    case dailyStreak = 0
    case interviewCountdown = 1
    case postInterviewReflection = 2

    init(mode: CVBoostaActivityAttributes.ActivityMode) {
        switch mode {
        case .dailyStreak:
            self = .dailyStreak
        case .interviewCountdown:
            self = .interviewCountdown
        case .postInterviewReflection:
            self = .postInterviewReflection
        default:
            self = .dailyStreak
        }
    }
}
