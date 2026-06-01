import Foundation

final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published private(set) var isPremium: Bool = false

    private init() {}

    func refreshEntitlements() {
        // Placeholder RevenueCat logic.
        // Keep false by default when keys are missing.
        let premium = UserDefaults.standard.bool(forKey: "cvboosta.isPremium")
        if Thread.isMainThread {
            isPremium = premium
        } else {
            DispatchQueue.main.async {
                self.isPremium = premium
            }
        }
    }

    func restorePurchases() async {
        // Placeholder for RevenueCat restore flow.
        // Intentionally no-op so app remains stable without keys.
        try? await Task.sleep(nanoseconds: 200_000_000)
        refreshEntitlements()
    }

    func unlockPremiumForDebug() {
        UserDefaults.standard.set(true, forKey: "cvboosta.isPremium")
        refreshEntitlements()
    }
}
