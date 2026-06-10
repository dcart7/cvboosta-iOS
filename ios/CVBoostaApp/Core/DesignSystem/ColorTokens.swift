import SwiftUI
import UIKit

enum BoostaColor {
    static let accent = Color(red: 0.19, green: 0.56, blue: 0.98)
    static let accentSecondary = adaptive(light: rgb(0.38, 0.73, 0.98), dark: rgb(0.52, 0.84, 1.0))
    static let accentDeep = adaptive(light: rgb(0.10, 0.34, 0.85), dark: rgb(0.05, 0.22, 0.74))
    static let success = adaptive(light: rgb(0.10, 0.69, 0.38), dark: rgb(0.23, 0.83, 0.52))
    static let warning = adaptive(light: rgb(0.90, 0.55, 0.06), dark: rgb(0.98, 0.73, 0.20))
    static let danger = adaptive(light: rgb(0.84, 0.24, 0.24), dark: rgb(1.0, 0.38, 0.38))

    static let pageTop = adaptive(light: rgb(0.96, 0.98, 1.0), dark: rgb(0.04, 0.08, 0.16))
    static let pageBottom = adaptive(light: rgb(0.92, 0.95, 0.99), dark: rgb(0.01, 0.03, 0.10))
    static let pageGlow = adaptive(light: rgb(0.56, 0.76, 1.0), dark: rgb(0.16, 0.38, 0.82))
    static let surface = adaptive(light: UIColor.white.withAlphaComponent(0.62), dark: rgb(0.08, 0.12, 0.21).withAlphaComponent(0.82))
    static let surfaceElevated = adaptive(light: UIColor.white.withAlphaComponent(0.82), dark: rgb(0.10, 0.15, 0.26).withAlphaComponent(0.92))
    static let surfaceMuted = adaptive(light: UIColor.white.withAlphaComponent(0.42), dark: rgb(0.06, 0.09, 0.17).withAlphaComponent(0.62))
    static let surfaceInteractive = adaptive(light: UIColor.white.withAlphaComponent(0.55), dark: rgb(0.09, 0.14, 0.24).withAlphaComponent(0.88))
    static let surfaceInteractiveStrong = adaptive(light: UIColor.white.withAlphaComponent(0.72), dark: rgb(0.12, 0.18, 0.30).withAlphaComponent(0.94))
    static let surfaceDisabled = adaptive(light: UIColor.white.withAlphaComponent(0.35), dark: rgb(0.07, 0.11, 0.19).withAlphaComponent(0.58))

    static let glassStroke = adaptive(light: UIColor.black.withAlphaComponent(0.06), dark: UIColor.white.withAlphaComponent(0.12))
    static let glassStrongStroke = adaptive(light: UIColor.black.withAlphaComponent(0.10), dark: UIColor.white.withAlphaComponent(0.18))
    static let glassShadow = adaptive(light: UIColor.black.withAlphaComponent(0.08), dark: UIColor.black.withAlphaComponent(0.32))
    static let glassHighlight = adaptive(light: UIColor.white.withAlphaComponent(0.14), dark: UIColor.white.withAlphaComponent(0.05))
    static let glassHighlightStrong = adaptive(light: UIColor.white.withAlphaComponent(0.22), dark: UIColor.white.withAlphaComponent(0.08))
    static let ringTrack = adaptive(light: UIColor.white.withAlphaComponent(0.35), dark: UIColor.white.withAlphaComponent(0.12))
    static let outlineSoft = adaptive(light: UIColor.white.withAlphaComponent(0.18), dark: UIColor.white.withAlphaComponent(0.14))
    static let outlineStrong = adaptive(light: UIColor.white.withAlphaComponent(0.80), dark: UIColor.white.withAlphaComponent(0.28))
    static let heatmapEmpty = adaptive(light: UIColor.white.withAlphaComponent(0.18), dark: UIColor.white.withAlphaComponent(0.08))
    static let primaryText = adaptive(light: rgb(0.10, 0.14, 0.20), dark: rgb(0.95, 0.97, 1.0))
    static let secondaryText = adaptive(light: rgb(0.35, 0.42, 0.52), dark: rgb(0.72, 0.79, 0.89))
    static let tertiaryText = adaptive(light: rgb(0.47, 0.56, 0.71), dark: rgb(0.56, 0.65, 0.78))

    static let gradientA = LinearGradient(
        colors: [accentSecondary, accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pageGradient = LinearGradient(
        colors: [pageTop, adaptive(light: rgb(0.88, 0.93, 0.99), dark: rgb(0.02, 0.08, 0.20)), pageBottom],
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

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}
