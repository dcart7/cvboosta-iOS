import Foundation

enum AppEnvironment {
    private static let productionAPIURL = URL(string: "https://cvboosta-backend-615826584976.europe-west3.run.app")!

    enum Mode: String {
        case development
        case staging
        case production
    }

    static var mode: Mode {
        if let env = ProcessInfo.processInfo.environment["CVBOOSTA_ENV"],
           let value = Mode(rawValue: env.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
            return value
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: "APP_ENV") as? String,
           let mode = Mode(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
            return mode
        }

        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    static var apiBaseURL: URL {
        if let override = resolvedAPIOverride() {
            return validatedAPIBaseURL(override)
        }

        switch mode {
        case .development:
            return URL(string: "http://127.0.0.1:8000")!
        case .staging:
            return productionAPIURL
        case .production:
            return productionAPIURL
        }
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

    static var appBundleIdentifierPlaceholder: String {
        (Bundle.main.object(forInfoDictionaryKey: "APP_BUNDLE_ID_PLACEHOLDER") as? String) ?? "com.cvboosta.app"
    }

    private static func resolvedAPIOverride() -> URL? {
        if let env = ProcessInfo.processInfo.environment["API_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: env),
           !env.isEmpty {
            return url
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }

            if let url = URL(string: trimmed) {
                return url
            }
        }

        return nil
    }

    private static func validatedAPIBaseURL(_ candidate: URL) -> URL {
        switch mode {
        case .development:
            return candidate
        case .staging, .production:
            guard candidate.host?.lowercased() == productionAPIURL.host?.lowercased() else {
                return productionAPIURL
            }
            return candidate
        }
    }
}
