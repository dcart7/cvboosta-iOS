import Foundation

final class HandoffService {
    static let shared = HandoffService()

    private init() {}

    func makeUserActivity(type: String, title: String, payload: [String: String]) -> NSUserActivity {
        let activity = NSUserActivity(activityType: type)
        activity.title = title
        activity.userInfo = payload
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = type as NSUserActivityPersistentIdentifier
        activity.becomeCurrent()
        return activity
    }
}
