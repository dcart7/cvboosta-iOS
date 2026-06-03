import SwiftUI

enum BoostaColor {
    static let accent = Color(red: 0.19, green: 0.56, blue: 0.98)
    static let accentSecondary = Color(red: 0.44, green: 0.82, blue: 1.0)
    static let accentDeep = Color(red: 0.05, green: 0.22, blue: 0.74)
    static let success = Color(red: 0.23, green: 0.83, blue: 0.52)
    static let warning = Color(red: 0.98, green: 0.73, blue: 0.20)
    static let danger = Color(red: 1.0, green: 0.38, blue: 0.38)

    static let pageTop = Color(red: 0.03, green: 0.07, blue: 0.16)
    static let pageBottom = Color(red: 0.01, green: 0.03, blue: 0.10)
    static let pageGlow = Color(red: 0.16, green: 0.38, blue: 0.82)
    static let surface = Color.white.opacity(0.08)
    static let surfaceElevated = Color.white.opacity(0.14)
    static let surfaceMuted = Color.white.opacity(0.05)

    static let glassStroke = Color.white.opacity(0.16)
    static let glassStrongStroke = Color.white.opacity(0.28)
    static let glassShadow = Color.black.opacity(0.32)
    static let primaryText = Color(red: 0.95, green: 0.97, blue: 1.0)
    static let secondaryText = Color(red: 0.64, green: 0.73, blue: 0.86)
    static let tertiaryText = Color(red: 0.47, green: 0.56, blue: 0.71)

    static let gradientA = LinearGradient(
        colors: [accentSecondary, accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pageGradient = LinearGradient(
        colors: [pageTop, Color(red: 0.02, green: 0.08, blue: 0.20), pageBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let auroraGradient = LinearGradient(
        colors: [
            accentSecondary.opacity(0.95),
            accent.opacity(0.85),
            accentDeep.opacity(0.88)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
