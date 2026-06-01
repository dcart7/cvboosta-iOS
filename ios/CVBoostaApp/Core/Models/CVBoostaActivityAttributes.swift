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

        init(mode: ActivityMode, title: String, detail: String, progress: Double = 0, etaText: String = "") {
            self.mode = mode
            self.title = title
            self.detail = detail
            self.progress = progress
            self.etaText = etaText
        }
    }

    enum ActivityMode: String, Codable, Hashable {
        case atsOptimization
        case tailoring
        case interviewCountdown
        case applicationStatus
        case dailyStreak
    }

    var activityName: String
}
