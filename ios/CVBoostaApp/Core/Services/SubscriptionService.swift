import Foundation
import StoreKit
import UIKit

private struct AppStoreTransactionSyncRequest: Encodable {
    let productId: String
    let transactionId: String
    let originalTransactionId: String
    let transactionJWS: String
    let productType: String
    let source: String
    let quantity: Int
    let purchaseDate: Date
    let originalPurchaseDate: Date
    let expiresAt: Date?
    let revocationDate: Date?
    let environment: String?
    let appAccountToken: String?
    let ownershipType: String?
    let subscriptionGroupId: String?
    let webOrderLineItemId: String?

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case transactionId = "transaction_id"
        case originalTransactionId = "original_transaction_id"
        case transactionJWS = "transaction_jws"
        case productType = "product_type"
        case source
        case quantity
        case purchaseDate = "purchase_date"
        case originalPurchaseDate = "original_purchase_date"
        case expiresAt = "expires_at"
        case revocationDate = "revocation_date"
        case environment
        case appAccountToken = "app_account_token"
        case ownershipType = "ownership_type"
        case subscriptionGroupId = "subscription_group_id"
        case webOrderLineItemId = "web_order_line_item_id"
    }
}

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

    @Published private(set) var storeProducts: [String: Product] = [:]
    @Published private(set) var isLoadingStoreProducts: Bool = false
    @Published private(set) var isRestoringStorePurchases: Bool = false
    @Published private(set) var purchaseInFlightProductID: String?
    @Published private(set) var storeStatusMessage: String?
    @Published private(set) var storeErrorMessage: String?
    @Published private(set) var scanCreditBalance: Int = 0

    private let client: AuthenticatedAPIClient
    private let defaults: UserDefaults

    private let localScanCreditsKey = "cvboosta.storekit.scanCredits"
    private let processedConsumableTransactionIDsKey = "cvboosta.storekit.processedConsumableTransactionIDs"

    private var transactionUpdatesTask: Task<Void, Never>?

    init(
        client: AuthenticatedAPIClient = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.defaults = defaults
        self.scanCreditBalance = max(defaults.integer(forKey: localScanCreditsKey), 0)
        startTransactionObserver()

        Task {
            await refreshStoreProducts()
            await syncUnfinishedTransactions()
        }
    }

    func prepareStore() async {
        await refreshStoreProducts()
    }

    func refreshEntitlements() {
        Task {
            await refreshStoreProducts()
            await syncFromBackend()
        }
    }

    func purchase(productID: String) async {
        storeStatusMessage = nil
        storeErrorMessage = nil

        if storeProducts[productID] == nil {
            await refreshStoreProducts()
        }

        guard let product = storeProducts[productID] else {
            storeErrorMessage = "This App Store product is not available yet."
            return
        }

        purchaseInFlightProductID = productID
        defer { purchaseInFlightProductID = nil }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try verifiedTransaction(from: verification)
                let synced = await processTransaction(
                    verification: verification,
                    transaction: transaction,
                    source: "purchase"
                )
                await transaction.finish()
                storeStatusMessage = successMessage(for: transaction, synced: synced)
            case .pending:
                storeStatusMessage = "Purchase is pending approval."
            case .userCancelled:
                storeStatusMessage = "Purchase cancelled."
            @unknown default:
                storeErrorMessage = "Unable to complete purchase."
            }
        } catch {
            storeErrorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        storeStatusMessage = nil
        storeErrorMessage = nil
        isRestoringStorePurchases = true
        defer { isRestoringStorePurchases = false }

        do {
            try await AppStore.sync()
            await syncCurrentEntitlementsToBackend()
            let refreshed = await syncFromBackend()
            storeStatusMessage = (refreshed || isPremium || scanCreditBalance > 0)
                ? "Purchases restored."
                : "No App Store purchases found."
        } catch {
            storeErrorMessage = error.localizedDescription
            _ = await syncFromBackend()
        }
    }

    func openManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .sorted(by: { $0.activationState == .foregroundActive && $1.activationState != .foregroundActive })
            .first
        else {
            storeErrorMessage = "Unable to open App Store subscription management."
            return
        }

        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            storeErrorMessage = error.localizedDescription
        }
    }

    func displayPrice(for productID: String, fallback: Double) -> String {
        if let product = storeProducts[productID] {
            return product.displayPrice
        }

        return fallback.formatted(.currency(code: "USD"))
    }

    func isProductAvailable(_ productID: String) -> Bool {
        storeProducts[productID] != nil
    }

    func isPurchasing(_ productID: String) -> Bool {
        purchaseInFlightProductID == productID
    }

    func purchaseButtonTitle(for productID: String) -> String {
        if purchaseInFlightProductID == productID {
            return "Processing..."
        }

        switch productID {
        case AppEnvironment.appStoreSingleScanProductID:
            return "Buy"
        case AppEnvironment.appStoreLifetimeProductID:
            return "Unlock"
        default:
            return "Subscribe"
        }
    }

    func shouldUseConsumableScanCredit(fallbackFreeRemaining: Int) -> Bool {
        guard !isPremium else { return false }
        let freeRemaining = max(scansRemainingToday ?? fallbackFreeRemaining, 0)
        return freeRemaining <= 0 && scanCreditBalance > 0
    }

    func consumeConsumableScanCredit() {
        guard scanCreditBalance > 0 else { return }
        scanCreditBalance -= 1
        defaults.set(scanCreditBalance, forKey: localScanCreditsKey)
        lastSyncedAt = Date()
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

    func consumeFreeOptimizationIfNeeded() {
        guard !isPremium else { return }

        if let scansRemainingToday {
            self.scansRemainingToday = max(scansRemainingToday - 1, 0)
        } else {
            self.scansRemainingToday = 0
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

    private func refreshStoreProducts() async {
        guard !isLoadingStoreProducts else { return }
        isLoadingStoreProducts = true
        defer { isLoadingStoreProducts = false }

        do {
            let products = try await Product.products(for: Self.storeProductIDs)
            storeProducts = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            storeErrorMessage = error.localizedDescription
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

            if let credits =
                payload.int("scan_credit_balance")
                ?? payload.int("scan_credits")
                ?? payload.int("single_scan_credits")
                ?? payload.int("consumable_scan_credits")
            {
                scanCreditBalance = max(credits, 0)
                defaults.set(scanCreditBalance, forKey: localScanCreditsKey)
            }

            if let expiresRaw = payload.string("expires_at") ?? payload.string("current_period_end") ?? payload.string("renewal_at") {
                expiresAt = Self.parseDate(expiresRaw)
            } else {
                expiresAt = nil
            }
            lastSyncedAt = Date()
            return true
        } catch {
            return false
        }
    }

    private func startTransactionObserver() {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handleTransactionUpdate(update)
            }
        }
    }

    private func syncUnfinishedTransactions() async {
        for await update in Transaction.unfinished {
            await handleTransactionUpdate(update)
        }
    }

    private func handleTransactionUpdate(_ verification: VerificationResult<Transaction>) async {
        do {
            let transaction = try verifiedTransaction(from: verification)
            let synced = await processTransaction(
                verification: verification,
                transaction: transaction,
                source: "update"
            )
            await transaction.finish()
            if synced && storeStatusMessage == nil {
                storeStatusMessage = successMessage(for: transaction, synced: true)
            }
        } catch {
            storeErrorMessage = error.localizedDescription
        }
    }

    private func syncCurrentEntitlementsToBackend() async {
        for productID in Self.restorableProductIDs {
            guard let verification = await Transaction.currentEntitlement(for: productID) else { continue }

            do {
                let transaction = try verifiedTransaction(from: verification)
                _ = await processTransaction(
                    verification: verification,
                    transaction: transaction,
                    source: "restore"
                )
            } catch {
                storeErrorMessage = error.localizedDescription
            }
        }
    }

    @discardableResult
    private func processTransaction(
        verification: VerificationResult<Transaction>,
        transaction: Transaction,
        source: String
    ) async -> Bool {
        applyLocalUnlock(from: transaction)

        if transaction.productID == AppEnvironment.appStoreSingleScanProductID {
            grantLocalConsumableCreditIfNeeded(transaction)
        }

        let synced = await syncTransactionToBackend(
            verification: verification,
            transaction: transaction,
            source: source
        )

        if synced {
            let refreshed = await syncFromBackend()
            if refreshed {
                storeErrorMessage = nil
            }
        }

        return synced
    }

    private func applyLocalUnlock(from transaction: Transaction) {
        switch transaction.productID {
        case AppEnvironment.appStoreGoMonthlyProductID:
            isPremium = true
            entitlement = "go"
            plan = "go"
            expiresAt = transaction.expirationDate
            source = "app_store"
            lastSyncedAt = Date()
        case AppEnvironment.appStoreProMonthlyProductID:
            isPremium = true
            entitlement = "pro"
            plan = "pro"
            expiresAt = transaction.expirationDate
            source = "app_store"
            lastSyncedAt = Date()
        case AppEnvironment.appStoreLifetimeProductID:
            isPremium = true
            entitlement = "lifetime"
            plan = "lifetime"
            expiresAt = nil
            source = "app_store"
            lastSyncedAt = Date()
        default:
            break
        }
    }

    private func grantLocalConsumableCreditIfNeeded(_ transaction: Transaction) {
        let transactionID = String(transaction.id)
        guard !processedConsumableTransactionIDs.contains(transactionID) else { return }

        scanCreditBalance += max(transaction.purchasedQuantity, 1)
        defaults.set(scanCreditBalance, forKey: localScanCreditsKey)
        rememberProcessedConsumableTransactionID(transactionID)
        lastSyncedAt = Date()
    }

    private func syncTransactionToBackend(
        verification: VerificationResult<Transaction>,
        transaction: Transaction,
        source: String
    ) async -> Bool {
        let request = AppStoreTransactionSyncRequest(
            productId: transaction.productID,
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            transactionJWS: verification.jwsRepresentation,
            productType: Self.productTypeName(transaction.productType),
            source: source,
            quantity: transaction.purchasedQuantity,
            purchaseDate: transaction.purchaseDate,
            originalPurchaseDate: transaction.originalPurchaseDate,
            expiresAt: transaction.expirationDate,
            revocationDate: transaction.revocationDate,
            environment: transaction.environment.rawValue,
            appAccountToken: transaction.appAccountToken?.uuidString,
            ownershipType: transaction.ownershipType.rawValue,
            subscriptionGroupId: transaction.subscriptionGroupID,
            webOrderLineItemId: transaction.webOrderLineItemID
        )

        do {
            let _: [String: JSONValue] = try await client.postJSON(
                path: AppEnvironment.appStoreTransactionSyncPath,
                body: request
            )
            return true
        } catch {
            return false
        }
    }

    private func successMessage(for transaction: Transaction, synced: Bool) -> String {
        if transaction.productID == AppEnvironment.appStoreSingleScanProductID {
            return synced
                ? "Single Scan added to your account."
                : "Single Scan is ready on this device. Backend sync will catch up when available."
        }

        return synced
            ? "Purchase completed and synced."
            : "Purchase completed. Local access is unlocked while backend sync retries."
    }

    private func verifiedTransaction(from verification: VerificationResult<Transaction>) throws -> Transaction {
        switch verification {
        case .verified(let transaction):
            return transaction
        case .unverified(_, let error):
            throw error
        }
    }

    private var processedConsumableTransactionIDs: [String] {
        defaults.stringArray(forKey: processedConsumableTransactionIDsKey) ?? []
    }

    private func rememberProcessedConsumableTransactionID(_ id: String) {
        var ids = processedConsumableTransactionIDs
        ids.append(id)
        if ids.count > 120 {
            ids.removeFirst(ids.count - 120)
        }
        defaults.set(ids, forKey: processedConsumableTransactionIDsKey)
    }
}

private extension SubscriptionService {
    static let storeProductIDs: [String] = [
        AppEnvironment.appStoreSingleScanProductID,
        AppEnvironment.appStoreGoMonthlyProductID,
        AppEnvironment.appStoreProMonthlyProductID,
        AppEnvironment.appStoreLifetimeProductID
    ]

    static let restorableProductIDs: [String] = [
        AppEnvironment.appStoreGoMonthlyProductID,
        AppEnvironment.appStoreProMonthlyProductID,
        AppEnvironment.appStoreLifetimeProductID
    ]

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

    static func productTypeName(_ type: Product.ProductType) -> String {
        switch type {
        case .autoRenewable:
            return "auto_renewable"
        case .nonConsumable:
            return "non_consumable"
        case .consumable:
            return "consumable"
        case .nonRenewable:
            return "non_renewable"
        default:
            return "unknown"
        }
    }
}
