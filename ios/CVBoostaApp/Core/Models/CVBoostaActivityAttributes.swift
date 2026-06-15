import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct CVBoostaActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var mode: ActivityMode
        var title: String
        var detail: String
        var progress: Double
        var etaText: String
        var badgeText: String?
        var compactTrailingText: String?

        init(
            mode: ActivityMode,
            title: String,
            detail: String,
            progress: Double = 0,
            etaText: String = "",
            badgeText: String? = nil,
            compactTrailingText: String? = nil
        ) {
            self.mode = mode
            self.title = title
            self.detail = detail
            self.progress = progress
            self.etaText = etaText
            self.badgeText = badgeText
            self.compactTrailingText = compactTrailingText
        }
    }

    enum ActivityMode: String, Codable, Hashable {
        case atsOptimization
        case tailoring
        case interviewCountdown
        case applicationStatus
        case dailyStreak
        case postInterviewReflection
    }

    var activityName: String
}
