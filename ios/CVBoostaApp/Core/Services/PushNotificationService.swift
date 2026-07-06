import Foundation
import UIKit
import UserNotifications

private struct APNSDeviceTokenRequest: Encodable {
    let token: String
    let bundleId: String
    let apnsEnvironment: String

    enum CodingKeys: String, CodingKey {
        case token
        case bundleId = "bundle_id"
        case apnsEnvironment = "apns_environment"
    }
}

private struct APNSRegisterResponse: Decodable {
    let message: String?
}

@MainActor
final class PushNotificationService: NSObject {
    static let shared = PushNotificationService()

    private let client: AuthenticatedAPIClient
    private let defaults: UserDefaults

    private let tokenStorageKey = "cvboosta.push.apns.token"
    private let lastSentTokenKey = "cvboosta.push.apns.last_sent"

    init(
        client: AuthenticatedAPIClient = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.defaults = defaults
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshRegistrationState() }
    }

    func requestAuthorizationIfNeeded(forcePrompt: Bool = true) async {
        guard notificationsEnabled else {
            await disableRemoteNotificationsIfNeeded()
            return
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            guard forcePrompt else { return }
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                // Ignore: user can enable later.
            }
        case .denied:
            await disableRemoteNotificationsIfNeeded()
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        @unknown default:
            break
        }
    }

    func applyUserPreference(isEnabled: Bool) async {
        defaults.set(isEnabled, forKey: AppPreferenceKeys.notificationsEnabled)

        guard isEnabled else {
            await deactivateCurrentTokenIfPossible()
            UIApplication.shared.unregisterForRemoteNotifications()
            return
        }

        await requestAuthorizationIfNeeded(forcePrompt: true)
        await syncIfPossible()
    }

    func refreshRegistrationState() async {
        guard notificationsEnabled else {
            await disableRemoteNotificationsIfNeeded()
            return
        }

        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        case .notDetermined:
            break
        case .denied:
            await disableRemoteNotificationsIfNeeded()
        @unknown default:
            break
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        defaults.set(token, forKey: tokenStorageKey)
        Task { await syncIfPossible() }
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        // Best effort. Push is optional.
        _ = error
    }

    func deactivateCurrentTokenIfPossible() async {
        guard let path = apnsDeactivatePath else { return }
        guard let requestBody = currentRequestBody() else { return }

        do {
            let _: APNSRegisterResponse = try await client.postJSON(
                path: path,
                body: requestBody
            )
            defaults.removeObject(forKey: lastSentTokenKey)
        } catch {
            // Best effort. We retry the normal registration flow on the next login/enable.
        }
    }

    func syncIfPossible() async {
        guard notificationsEnabled else { return }

        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined, .denied:
            return
        @unknown default:
            return
        }

        guard let path = apnsRegisterPath else { return }

        guard let token = defaults.string(forKey: tokenStorageKey),
              !token.isEmpty
        else { return }

        let lastSent = defaults.string(forKey: lastSentTokenKey)
        guard lastSent != token else { return }

        do {
            let _: APNSRegisterResponse = try await client.postJSON(
                path: path,
                body: APNSDeviceTokenRequest(
                    token: token,
                    bundleId: Bundle.main.bundleIdentifier ?? AppEnvironment.appBundleIdentifierPlaceholder,
                    apnsEnvironment: AppEnvironment.apnsEnvironment.rawValue
                )
            )
            defaults.set(token, forKey: lastSentTokenKey)
        } catch {
            // Backend may not support APNs yet; retry next launch/login.
        }
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        _ = response
        Task { @MainActor in
            UIApplication.shared.applicationIconBadgeNumber = 0
            await PushNotificationService.shared.syncIfPossible()
        }
        completionHandler()
    }
}

private extension PushNotificationService {
    var notificationsEnabled: Bool {
        guard defaults.object(forKey: AppPreferenceKeys.notificationsEnabled) != nil else {
            return true
        }
        return defaults.bool(forKey: AppPreferenceKeys.notificationsEnabled)
    }

    var apnsRegisterPath: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "APNS_REGISTER_PATH") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var apnsDeactivatePath: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "APNS_DEACTIVATE_PATH") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var hasActiveBackendRegistration: Bool {
        guard let lastSentToken = defaults.string(forKey: lastSentTokenKey) else {
            return false
        }
        return !lastSentToken.isEmpty
    }

    func currentRequestBody() -> APNSDeviceTokenRequest? {
        guard let token = defaults.string(forKey: tokenStorageKey),
              !token.isEmpty
        else {
            return nil
        }

        return APNSDeviceTokenRequest(
            token: token,
            bundleId: Bundle.main.bundleIdentifier ?? AppEnvironment.appBundleIdentifierPlaceholder,
            apnsEnvironment: AppEnvironment.apnsEnvironment.rawValue
        )
    }

    func disableRemoteNotificationsIfNeeded() async {
        if hasActiveBackendRegistration {
            await deactivateCurrentTokenIfPossible()
        }
        UIApplication.shared.unregisterForRemoteNotifications()
    }
}
