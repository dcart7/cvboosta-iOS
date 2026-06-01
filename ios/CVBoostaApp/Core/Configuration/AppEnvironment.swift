import Foundation

enum AppEnvironment {
    static var apiBaseURL: URL {
        if let env = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: env),
           !env.isEmpty {
            return url
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: value),
           !value.isEmpty {
            return url
        }

        return URL(string: "http://127.0.0.1:8000")!
    }

    static var webBaseURL: URL {
        if let env = ProcessInfo.processInfo.environment["WEB_BASE_URL"],
           let url = URL(string: env),
           !env.isEmpty {
            return url
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: "WEB_BASE_URL") as? String,
           let url = URL(string: value),
           !value.isEmpty {
            return url
        }

        return URL(string: "https://cvboosta.com")!
    }

    static var demoFallbackEnabled: Bool {
        if let env = ProcessInfo.processInfo.environment["DEMO_FALLBACK_ENABLED"] {
            return NSString(string: env).boolValue
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: "DEMO_FALLBACK_ENABLED") as? Bool {
            return value
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: "DEMO_FALLBACK_ENABLED") as? String {
            return NSString(string: value).boolValue
        }

        return true
    }

    static var appBundleIdentifierPlaceholder: String {
        (Bundle.main.object(forInfoDictionaryKey: "APP_BUNDLE_ID_PLACEHOLDER") as? String) ?? "com.cvboosta.app"
    }
}
