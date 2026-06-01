import Foundation

final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published private(set) var isPremium: Bool = false
    @Published private(set) var entitlement: String?
    @Published private(set) var expiresAt: Date?

    private init() {}

    func refreshEntitlements() {
        // Entitlements are sourced from backend auth state.
    }

    func restorePurchases() async {
        // Placeholder for future server-side restore endpoint integration.
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    func applyBackendSubscription(_ snapshot: AuthSubscription) {
        if Thread.isMainThread {
            isPremium = snapshot.isActive
            entitlement = snapshot.entitlement
            expiresAt = snapshot.expiresAt
        } else {
            DispatchQueue.main.async {
                self.isPremium = snapshot.isActive
                self.entitlement = snapshot.entitlement
                self.expiresAt = snapshot.expiresAt
            }
        }
    }

    func reset() {
        if Thread.isMainThread {
            isPremium = false
            entitlement = nil
            expiresAt = nil
        } else {
            DispatchQueue.main.async {
                self.isPremium = false
                self.entitlement = nil
                self.expiresAt = nil
            }
        }
    }
}
