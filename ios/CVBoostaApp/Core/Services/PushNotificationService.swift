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
    }

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
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
        // Production backend currently does not expose a documented APNs registration endpoint.
        // If/when backend support is added, set `APNS_REGISTER_PATH` in Info.plist (e.g. `/devices/apns`).
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

extension PushNotificationService: UNUserNotificationCenterDelegate {}

private extension PushNotificationService {
    var apnsRegisterPath: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "APNS_REGISTER_PATH") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
