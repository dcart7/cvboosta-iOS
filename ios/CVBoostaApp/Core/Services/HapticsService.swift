import UIKit

@MainActor
enum HapticsService {
    private static let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let softImpactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidImpactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    private static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: AppPreferenceKeys.hapticsEnabled) != nil else {
            return true
        }
        return defaults.bool(forKey: AppPreferenceKeys.hapticsEnabled)
    }

    static func tap() {
        impact(.light)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        let generator: UIImpactFeedbackGenerator = switch style {
        case .light:
            lightImpactGenerator
        case .medium:
            mediumImpactGenerator
        case .heavy:
            heavyImpactGenerator
        case .soft:
            softImpactGenerator
        case .rigid:
            rigidImpactGenerator
        @unknown default:
            mediumImpactGenerator
        }
        generator.prepare()
        generator.impactOccurred()
        generator.prepare()
    }

    static func selection() {
        guard isEnabled else { return }
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    static func success() {
        notify(.success)
    }

    static func warning() {
        notify(.warning)
    }

    static func error() {
        notify(.error)
    }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }
}
