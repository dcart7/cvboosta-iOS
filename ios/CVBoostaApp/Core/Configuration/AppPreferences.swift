import SwiftUI

enum AppPreferenceKeys {
    static let appearance = "cvboosta.appearance"
    static let hapticsEnabled = "cvboosta.hapticsEnabled"
    static let biometricsEnabled = "cvboosta.biometricsEnabled"
    static let notificationsEnabled = "cvboosta.notificationsEnabled"
}

enum AppAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
