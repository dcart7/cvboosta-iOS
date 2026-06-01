import Foundation

struct ScanLimitStatus: Equatable {
    let canScan: Bool
    let scansRemaining: Int
    let resetDate: Date
}

final class ScanLimitService {
    static let shared = ScanLimitService()

    private let dailyLimit = 1
    private let calendar = Calendar.current
    private let defaults: UserDefaults

    private let dateKey = "cvboosta.scanLimit.date"
    private let countKey = "cvboosta.scanLimit.count"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func status(isPremium: Bool, now: Date = .now) -> ScanLimitStatus {
        if isPremium {
            return ScanLimitStatus(canScan: true, scansRemaining: Int.max, resetDate: nextReset(from: now))
        }

        resetIfNeeded(now: now)

        let count = defaults.integer(forKey: countKey)
        let remaining = max(dailyLimit - count, 0)

        return ScanLimitStatus(canScan: remaining > 0, scansRemaining: remaining, resetDate: nextReset(from: now))
    }

    func recordScan(isPremium: Bool, now: Date = .now) {
        guard !isPremium else { return }

        resetIfNeeded(now: now)

        let count = defaults.integer(forKey: countKey)
        defaults.set(count + 1, forKey: countKey)
        defaults.set(now.timeIntervalSince1970, forKey: dateKey)
    }

    func debugReset() {
        defaults.removeObject(forKey: dateKey)
        defaults.removeObject(forKey: countKey)
    }

    private func resetIfNeeded(now: Date) {
        guard let lastDate = storedDate() else {
            defaults.set(now.timeIntervalSince1970, forKey: dateKey)
            return
        }

        if !calendar.isDate(lastDate, inSameDayAs: now) {
            defaults.set(0, forKey: countKey)
            defaults.set(now.timeIntervalSince1970, forKey: dateKey)
        }
    }

    private func storedDate() -> Date? {
        let stamp = defaults.double(forKey: dateKey)
        guard stamp > 0 else { return nil }
        return Date(timeIntervalSince1970: stamp)
    }

    private func nextReset(from now: Date) -> Date {
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? now
    }
}
