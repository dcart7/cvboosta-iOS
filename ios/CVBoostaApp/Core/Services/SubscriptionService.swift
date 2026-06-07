import Foundation

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published private(set) var isPremium: Bool = false
    @Published private(set) var entitlement: String?
    @Published private(set) var expiresAt: Date?
    @Published private(set) var source: String?
    @Published private(set) var plan: String = "free"
    @Published private(set) var scansDailyLimit: Int?
    @Published private(set) var scansRemainingToday: Int?
    @Published private(set) var lastSyncedAt: Date?

    private let client: AuthenticatedAPIClient

    init(client: AuthenticatedAPIClient = .shared) {
        self.client = client
    }

    func refreshEntitlements() {
        Task {
            await syncFromBackend()
        }
    }

    func restorePurchases() async {
        // Source of truth is the backend subscription snapshot.
        // If the user purchased on another device/web, this will pick it up.
        await syncFromBackend()
    }

    @discardableResult
    func syncFromBackend() async -> Bool {
        await refreshFromBackend()
    }

    func applyBackendSubscription(_ snapshot: AuthSubscription) {
        if Thread.isMainThread {
            isPremium = snapshot.isActive
            entitlement = snapshot.entitlement
            expiresAt = snapshot.expiresAt
            source = snapshot.source
            lastSyncedAt = Date()
        } else {
            DispatchQueue.main.async {
                self.isPremium = snapshot.isActive
                self.entitlement = snapshot.entitlement
                self.expiresAt = snapshot.expiresAt
                self.source = snapshot.source
                self.lastSyncedAt = Date()
            }
        }
    }

    func applyBackendUsageLimits(_ snapshot: AuthUsageLimits) {
        if Thread.isMainThread {
            plan = snapshot.plan
            scansDailyLimit = snapshot.scansDailyLimit
            scansRemainingToday = snapshot.scansRemainingToday
            lastSyncedAt = Date()
        } else {
            DispatchQueue.main.async {
                self.plan = snapshot.plan
                self.scansDailyLimit = snapshot.scansDailyLimit
                self.scansRemainingToday = snapshot.scansRemainingToday
                self.lastSyncedAt = Date()
            }
        }
    }

    func reset() {
        if Thread.isMainThread {
            isPremium = false
            entitlement = nil
            expiresAt = nil
            source = nil
            plan = "free"
            scansDailyLimit = nil
            scansRemainingToday = nil
            lastSyncedAt = nil
        } else {
            DispatchQueue.main.async {
                self.isPremium = false
                self.entitlement = nil
                self.expiresAt = nil
                self.source = nil
                self.plan = "free"
                self.scansDailyLimit = nil
                self.scansRemainingToday = nil
                self.lastSyncedAt = nil
            }
        }
    }

    private func refreshFromBackend() async -> Bool {
        do {
            let payload: [String: JSONValue] = try await client.getJSON(path: "/billing/status")

            let planName =
                payload.string("entitlement")
                ?? payload.string("plan")
                ?? payload.string("tier")
                ?? payload.string("plan_name")
                ?? payload.string("subscription_tier")
                ?? payload.string("subscription_plan")

            let active = Self.inferredSubscriptionActive(from: payload, entitlement: planName)

            isPremium = active
            entitlement = planName ?? (active ? "premium" : "free")
            source = payload.string("source") ?? "stripe"

            plan =
                payload.string("plan")
                ?? payload.string("tier")
                ?? payload.string("plan_name")
                ?? payload.string("subscription_tier")
                ?? payload.string("subscription_plan")
                ?? (active ? "premium" : "free")
            scansDailyLimit = payload.int("scans_daily_limit") ?? payload.int("daily_limit")
            scansRemainingToday = payload.int("scans_remaining_today") ?? payload.int("remaining_today")

            if let expiresRaw = payload.string("expires_at") ?? payload.string("current_period_end") ?? payload.string("renewal_at") {
                expiresAt = Self.parseDate(expiresRaw)
            } else {
                expiresAt = nil
            }
            lastSyncedAt = Date()
            return true
        } catch {
            // Best-effort refresh. UI can still rely on `/auth/me` snapshots.
            return false
        }
    }
}

private extension SubscriptionService {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parseDate(_ value: String) -> Date? {
        iso8601WithFractional.date(from: value) ?? iso8601.date(from: value)
    }

    static func inferredSubscriptionActive(from payload: [String: JSONValue], entitlement: String?) -> Bool {
        if let direct = payload.bool("is_active")
            ?? payload.bool("active")
            ?? payload.bool("is_premium")
            ?? payload.bool("premium")
            ?? payload.bool("subscribed")
            ?? payload.bool("has_subscription")
        {
            return direct
        }

        let status =
            payload.string("status")
            ?? payload.string("subscription_status")
            ?? payload.string("billing_status")

        if let status {
            switch status.lowercased() {
            case "active", "paid", "premium", "pro", "trialing", "trial", "grace_period":
                return true
            case "free", "inactive", "canceled", "cancelled", "expired":
                return false
            default:
                break
            }
        }

        if let entitlement {
            switch entitlement.lowercased() {
            case "free", "basic", "none":
                return false
            default:
                return true
            }
        }

        return false
    }
}
