import Foundation

struct SharedStreakSnapshot: Hashable {
    let restoreDayStamp: String
    let freezeDayStamp: String
    let updatedAt: Date

    var isEmpty: Bool {
        restoreDayStamp.isEmpty && freezeDayStamp.isEmpty
    }
}

enum SharedStreakState {
    static let restoreDayKey = "cvboosta.streak.restore.day"
    static let freezeDayKey = "cvboosta.streak.freeze.day"
    static let updatedAtKey = "cvboosta.streak.updated_at"
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

    static func currentSnapshot(defaults: UserDefaults? = sharedDefaults) -> SharedStreakSnapshot {
        let updatedAt: Date
        if let rawDate = defaults?.object(forKey: updatedAtKey) as? Date {
            updatedAt = rawDate
        } else if let rawInterval = defaults?.object(forKey: updatedAtKey) as? Double {
            updatedAt = Date(timeIntervalSinceReferenceDate: rawInterval)
        } else {
            updatedAt = .distantPast
        }

        return SharedStreakSnapshot(
            restoreDayStamp: defaults?.string(forKey: restoreDayKey) ?? "",
            freezeDayStamp: defaults?.string(forKey: freezeDayKey) ?? "",
            updatedAt: updatedAt
        )
    }

    static func apply(snapshot: SharedStreakSnapshot, defaults: UserDefaults? = sharedDefaults) {
        defaults?.set(snapshot.restoreDayStamp, forKey: restoreDayKey)
        defaults?.set(snapshot.freezeDayStamp, forKey: freezeDayKey)
        defaults?.set(snapshot.updatedAt.timeIntervalSinceReferenceDate, forKey: updatedAtKey)
    }

    static func restoreYesterday(
        now: Date = .now,
        calendar: Calendar = .current,
        defaults: UserDefaults? = sharedDefaults
    ) {
        let stamp = dayStamp(for: calendar.date(byAdding: .day, value: -1, to: now) ?? now, calendar: calendar)
        defaults?.set(stamp, forKey: restoreDayKey)
        defaults?.set(Date().timeIntervalSinceReferenceDate, forKey: updatedAtKey)
    }

    static func freezeToday(now: Date = .now, defaults: UserDefaults? = sharedDefaults) {
        defaults?.set(dayStamp(for: now), forKey: freezeDayKey)
        defaults?.set(Date().timeIntervalSinceReferenceDate, forKey: updatedAtKey)
    }

    private static func dayStamp(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
