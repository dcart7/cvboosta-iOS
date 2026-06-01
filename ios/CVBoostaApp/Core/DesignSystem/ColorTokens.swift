import SwiftUI

enum BoostaColor {
    static let accent = Color(red: 0.08, green: 0.47, blue: 0.95)
    static let success = Color(red: 0.13, green: 0.69, blue: 0.35)
    static let warning = Color(red: 0.96, green: 0.62, blue: 0.11)
    static let danger = Color(red: 0.91, green: 0.24, blue: 0.22)

    static let pageTop = Color(red: 0.95, green: 0.97, blue: 1.0)
    static let pageBottom = Color(red: 0.91, green: 0.95, blue: 1.0)

    static let glassStroke = Color.white.opacity(0.42)
    static let glassShadow = Color.black.opacity(0.15)
    static let primaryText = Color(red: 0.08, green: 0.11, blue: 0.18)
    static let secondaryText = Color(red: 0.25, green: 0.3, blue: 0.39)

    static let gradientA = LinearGradient(
        colors: [Color(red: 0.58, green: 0.82, blue: 1.0), Color(red: 0.33, green: 0.58, blue: 0.95)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
