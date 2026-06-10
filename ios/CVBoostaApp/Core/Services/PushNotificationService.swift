import Foundation
import UIKit
import UserNotifications

private struct APNSRegisterRequest: Encodable {
    let token: String
    let bundleId: String

    enum CodingKeys: String, CodingKey {
        case token
        case bundleId = "bundle_id"
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
            UIApplication.shared.unregisterForRemoteNotifications()
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
            break
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        @unknown default:
            break
        }
    }

    func applyUserPreference(isEnabled: Bool) async {
        defaults.set(isEnabled, forKey: AppPreferenceKeys.notificationsEnabled)

        guard isEnabled else {
            UIApplication.shared.unregisterForRemoteNotifications()
            return
        }

        await requestAuthorizationIfNeeded(forcePrompt: true)
        await syncIfPossible()
    }

    func refreshRegistrationState() async {
        guard notificationsEnabled else {
            UIApplication.shared.unregisterForRemoteNotifications()
            return
        }

        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        case .notDetermined, .denied:
            break
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
            let bundleId = Bundle.main.bundleIdentifier ?? AppEnvironment.appBundleIdentifierPlaceholder
            let _: APNSRegisterResponse = try await client.postJSON(
                path: path,
                body: APNSRegisterRequest(token: token, bundleId: bundleId)
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
}
