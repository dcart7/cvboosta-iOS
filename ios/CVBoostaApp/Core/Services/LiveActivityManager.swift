import ActivityKit
import Foundation

@MainActor
@available(iOS 16.1, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<CVBoostaActivityAttributes>?

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
            currentActivity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
        } catch {
            print("Failed to start live activity: \(error)")
        }
    }

    func update(progress: Double, detail: String, etaText: String) async {
        guard let activity = currentActivity else { return }

        let newState = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS Optimization",
            detail: detail,
            progress: progress,
            etaText: etaText
        )

        await activity.update(.init(state: newState, staleDate: nil))
    }

    func end() async {
        guard let activity = currentActivity else { return }
        await activity.end(dismissalPolicy: .immediate)
        currentActivity = nil
    }

    func complete(finalScore: Int) async {
        guard let activity = currentActivity else { return }

        let completed = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS Scan Complete",
            detail: "Final score: \(finalScore)",
            progress: 1.0,
            etaText: ""
        )

        await activity.update(.init(state: completed, staleDate: nil))
        await activity.end(dismissalPolicy: .default)
        currentActivity = nil
    }

    func fail() async {
        guard let activity = currentActivity else { return }

        let failed = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS Scan Failed",
            detail: "Please try again",
            progress: 0.0,
            etaText: ""
        )

        await activity.update(.init(state: failed, staleDate: nil))
        await activity.end(dismissalPolicy: .default)
        currentActivity = nil
    }
}
