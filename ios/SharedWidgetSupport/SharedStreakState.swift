import Foundation

enum SharedStreakState {
    static let restoreDayKey = "cvboosta.streak.restore.day"
    static let freezeDayKey = "cvboosta.streak.freeze.day"
    static let sharedDefaults = UserDefaults(suiteName: CVBoostaWidgetStore.appGroupID)

    static func protectedDayStamps(
        restoredDayStamp: String? = nil,
        frozenDayStamp: String? = nil,
        defaults: UserDefaults? = sharedDefaults
    ) -> Set<String> {
        let restoreValue = restoredDayStamp ?? defaults?.string(forKey: restoreDayKey) ?? ""
        let freezeValue = frozenDayStamp ?? defaults?.string(forKey: freezeDayKey) ?? ""

        return Set([restoreValue, freezeValue].filter { !$0.isEmpty })
    }
}
