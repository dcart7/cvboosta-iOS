import SwiftUI

private struct WorkspaceButtonLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .allowsTightening(true)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: WorkspaceLayoutMetrics.controlMinHeight)
    }
}

extension View {
    func workspaceButtonLabelLayout() -> some View {
        modifier(WorkspaceButtonLabelModifier())
    }
}

struct BoostaDepthButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.982
    var pressedOpacity: Double = 0.97
    var verticalOffset: CGFloat = 1.5

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .offset(y: configuration.isPressed ? verticalOffset : 0)
            .brightness(configuration.isPressed ? -0.01 : 0)
            .animation(BoostaMotion.snap, value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            HapticsService.tap()
            action()
        } label: {
            HStack(spacing: BoostaSpace.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                Text(title)
                    .font(BoostaType.bodyStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                    .layoutPriority(1)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .opacity(isLoading ? 0 : 0.9)
            }
            .frame(maxWidth: .infinity, minHeight: WorkspaceLayoutMetrics.controlMinHeight)
            .padding(.horizontal, BoostaSpace.md)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                    .fill(
                        isDisabled
                        ? AnyShapeStyle(BoostaColor.accent.opacity(0.35))
                        : AnyShapeStyle(BoostaColor.auroraGradient)
                    )
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [BoostaColor.glassHighlightStrong, .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .blendMode(.screen)
            }
        }
        .buttonStyle(BoostaDepthButtonStyle())
        .foregroundStyle(.white)
        .overlay(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(isDisabled ? BoostaColor.glassHighlight : BoostaColor.outlineSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        .shadow(color: BoostaColor.accent.opacity(isDisabled ? 0 : 0.22), radius: 18, x: 0, y: 12)
        .disabled(isLoading || isDisabled)
        .accessibilityLabel(title)
    }
}

struct SecondaryButton: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            HapticsService.tap()
            action()
        } label: {
            Text(title)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
                .workspaceButtonLabelLayout()
                .padding(.horizontal, BoostaSpace.md)
                .padding(.vertical, 14)
                .background(BoostaColor.surfaceElevated)
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [BoostaColor.glassHighlight, .clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .blendMode(.screen)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                        .stroke(BoostaColor.glassStrongStroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        }
        .buttonStyle(BoostaDepthButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
        .accessibilityLabel(title)
    }
}

struct ResumeExportCapabilitiesView: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BoostaSpace.xs) {
                exportPill(for: .pdf)
                exportPill(for: .docx)
                exportPill(for: .txt)
            }

            VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                exportPill(for: .pdf)
                exportPill(for: .docx)
                exportPill(for: .txt)
            }
        }
    }

    private func exportPill(for format: ResumeExportFormat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(format.title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.primaryText)
                .lineLimit(1)

            Text(format.subtitle)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(BoostaColor.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BoostaSpace.sm)
        .padding(.vertical, 10)
        .background(BoostaColor.surfaceMuted)
        .overlay(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(BoostaColor.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
    }
}

struct TextInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var secure: Bool = false
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var errorText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.xs) {
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)

            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                }
            }
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(true)
            .textContentType(textContentType)
            .padding(.horizontal, BoostaSpace.sm)
            .padding(.vertical, 13)
            .background(BoostaColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                    .stroke(errorText == nil ? BoostaColor.glassStroke : BoostaColor.danger.opacity(0.85), lineWidth: 1)
            )
            .foregroundStyle(BoostaColor.primaryText)

            if let errorText {
                Text(errorText)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.danger)
            }
        }
    }
}

struct ScoreRing: View {
    let score: Int
    var lineWidth: CGFloat = 12

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        min(max(Double(score) / 100, 0), 1)
    }

    private var scoreColor: Color {
        switch score {
        case 80...100:
            return BoostaColor.success
        case 60...79:
            return BoostaColor.warning
        default:
            return BoostaColor.danger
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(BoostaColor.ringTrack, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.86), value: animatedProgress)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("/100")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: score) { _, _ in
            animatedProgress = progress
        }
        .shadow(color: scoreColor.opacity(0.18), radius: 18, x: 0, y: 8)
        .accessibilityLabel("ATS score \(score) out of 100")
    }
}

enum KeywordStatus {
    case missing
    case weak
    case present

    var title: String {
        switch self {
        case .missing: return "Missing"
        case .weak: return "Weak"
        case .present: return "Present"
        }
    }

    var color: Color {
        switch self {
        case .missing: return BoostaColor.danger
        case .weak: return BoostaColor.warning
        case .present: return BoostaColor.success
        }
    }
}

struct KeywordChip: View {
    let text: String
    let status: KeywordStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(BoostaType.caption)
        }
        .padding(.horizontal, BoostaSpace.sm)
        .padding(.vertical, 7)
        .background(BoostaColor.surfaceElevated)
        .clipShape(Capsule())
        .accessibilityLabel("\(text), \(status.title)")
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: BoostaSpace.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(BoostaColor.danger)
            Text(message)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.primaryText)
            Spacer(minLength: 0)
        }
        .padding(BoostaSpace.sm)
        .background(BoostaColor.danger.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(BoostaColor.danger.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        .accessibilityLabel(message)
    }
}

struct LoadingOverlay: View {
    let title: String
    let steps: [String]
    let currentStep: Int
    let progress: Double
    var onCancel: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            GlassCard(padding: BoostaSpace.lg) {
                VStack(alignment: .leading, spacing: BoostaSpace.md) {
                    Text(title)
                        .font(BoostaType.section)
                    ProgressView(value: progress)
                        .tint(BoostaColor.accent)

                    VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { idx, item in
                            HStack(spacing: BoostaSpace.xs) {
                                Image(systemName: idx <= currentStep ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(idx <= currentStep ? BoostaColor.accent : BoostaColor.secondaryText.opacity(0.5))
                                Text(item)
                                    .font(BoostaType.caption)
                                    .foregroundStyle(BoostaColor.secondaryText)
                            }
                        }
                    }

                    if let onCancel {
                        SecondaryButton(title: "Cancel", action: onCancel)
                    }
                }
            }
            .padding(.horizontal, BoostaSpace.md)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.xxs) {
            Text(title)
                .font(BoostaType.section)
                .foregroundStyle(BoostaColor.primaryText)
            if let subtitle {
                Text(subtitle)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(spacing: BoostaSpace.sm) {
                Image(systemName: "tray")
                    .font(.system(size: 28))
                    .foregroundStyle(BoostaColor.secondaryText)
                Text(title)
                    .font(BoostaType.section)
                Text(message)
                    .multilineTextAlignment(.center)
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
                PrimaryButton(title: actionTitle, action: action)
            }
        }
    }
}

enum WorkspaceLayoutMetrics {
    static let gridSpacing = BoostaSpace.md
    static let controlMinHeight: CGFloat = 52
    static let metricPillMinHeight: CGFloat = 60
    static let cardTileMinHeight: CGFloat = 96
    static let ringCardMinHeight: CGFloat = 118

    static func horizontalPadding(for width: CGFloat) -> CGFloat {
        if width >= 1360 {
            return BoostaSpace.xl
        }
        if width >= 900 {
            return BoostaSpace.lg
        }
        return BoostaSpace.md
    }

    static func columnCount(
        for width: CGFloat,
        minCardWidth: CGFloat,
        maxColumns: Int,
        horizontalPadding: CGFloat? = nil,
        spacing: CGFloat = gridSpacing
    ) -> Int {
        let padding = horizontalPadding ?? self.horizontalPadding(for: width)
        let availableWidth = max(width - (padding * 2), minCardWidth)
        var bestCount = 1

        for count in 1...maxColumns {
            let totalSpacing = CGFloat(count - 1) * spacing
            let cardWidth = (availableWidth - totalSpacing) / CGFloat(count)
            if cardWidth >= minCardWidth {
                bestCount = count
            }
        }

        return bestCount
    }
}

#if DEBUG
struct UIComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: BoostaSpace.md) {
            PrimaryButton(title: "Primary") {}
            SecondaryButton(title: "Secondary") {}
            ScoreRing(score: 78)
                .frame(width: 120, height: 120)
            KeywordChip(text: "REST API", status: .missing)
        }
        .padding()
        .background(LinearGradient(colors: [BoostaColor.pageTop, BoostaColor.pageBottom], startPoint: .top, endPoint: .bottom))
    }
}
#endif
