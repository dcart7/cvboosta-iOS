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
            .padding(.horizontal, BoostaSpace.md)
            .frame(maxWidth: .infinity, minHeight: WorkspaceLayoutMetrics.controlMinHeight)
            .background(
                RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                    .fill(isDisabled ? BoostaColor.accent.opacity(0.3) : BoostaColor.accent)
            )
        }
        .buttonStyle(BoostaDepthButtonStyle())
        .foregroundStyle(.white)
        .overlay(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(isDisabled ? BoostaColor.glassHighlight : BoostaColor.outlineSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        .shadow(color: BoostaColor.accent.opacity(isDisabled ? 0 : 0.18), radius: 12, x: 0, y: 8)
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
                .background(BoostaColor.surfaceElevated)
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
    var showsVisibilityToggle: Bool = false
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var errorText: String? = nil

    @State private var revealsSecureText = false

    var body: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.xs) {
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)

            HStack(spacing: BoostaSpace.xs) {
                Group {
                    if secure && !revealsSecureText {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .keyboardType(keyboardType)

                if secure && showsVisibilityToggle {
                    Button {
                        revealsSecureText.toggle()
                        HapticsService.selection()
                    } label: {
                        Image(systemName: revealsSecureText ? "eye.slash" : "eye")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BoostaColor.secondaryText)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(revealsSecureText ? "Hide password" : "Show password")
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
    static let controlMinHeight: CGFloat = 48
    static let metricPillMinHeight: CGFloat = 68
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

private struct WorkspaceColumnSpanKey: LayoutValueKey {
    static let defaultValue = 1
}

extension View {
    func workspaceColumnSpan(_ span: Int) -> some View {
        layoutValue(key: WorkspaceColumnSpanKey.self, value: max(1, span))
    }
}

struct WorkspaceMasonryLayout: Layout {
    let columns: Int
    let spacing: CGFloat

    init(columns: Int, spacing: CGFloat = WorkspaceLayoutMetrics.gridSpacing) {
        self.columns = max(1, columns)
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let layout = computeLayout(
            width: resolvedWidth(from: proposal, subviews: subviews),
            subviews: subviews
        )
        return layout.containerSize
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let layout = computeLayout(width: bounds.width, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            guard index < layout.frames.count else { continue }
            let frame = layout.frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func resolvedWidth(from proposal: ProposedViewSize, subviews: Subviews) -> CGFloat {
        if let width = proposal.width, width > 0 {
            return width
        }

        let fallbackWidth = subviews
            .map { $0.sizeThatFits(.unspecified).width }
            .max() ?? 320

        let totalSpacing = spacing * CGFloat(columns - 1)
        return max(fallbackWidth * CGFloat(columns) + totalSpacing, fallbackWidth)
    }

    private func computeLayout(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], containerSize: CGSize) {
        let totalSpacing = spacing * CGFloat(columns - 1)
        let columnWidth = max((width - totalSpacing) / CGFloat(columns), 0)
        var columnHeights = Array(repeating: CGFloat.zero, count: columns)
        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count)

        for subview in subviews {
            let requestedSpan = subview[WorkspaceColumnSpanKey.self]
            let span = min(max(1, requestedSpan), columns)
            let itemWidth = columnWidth * CGFloat(span) + spacing * CGFloat(span - 1)

            let placement: (column: Int, y: CGFloat)
            if span == columns {
                placement = (0, columnHeights.max() ?? 0)
            } else {
                var bestColumn = 0
                var bestY = CGFloat.greatestFiniteMagnitude

                for startColumn in 0...(columns - span) {
                    let candidateY = columnHeights[startColumn..<(startColumn + span)].max() ?? 0
                    if candidateY < bestY - 0.5 || (abs(candidateY - bestY) <= 0.5 && startColumn < bestColumn) {
                        bestColumn = startColumn
                        bestY = candidateY
                    }
                }

                placement = (bestColumn, bestY)
            }

            let proposedSize = ProposedViewSize(width: itemWidth, height: nil)
            let measuredSize = subview.sizeThatFits(proposedSize)
            let originX = CGFloat(placement.column) * (columnWidth + spacing)
            let frame = CGRect(
                x: originX,
                y: placement.y,
                width: itemWidth,
                height: measuredSize.height
            )
            frames.append(frame)

            let nextHeight = frame.maxY + spacing
            for column in placement.column..<(placement.column + span) {
                columnHeights[column] = nextHeight
            }
        }

        let contentHeight = max((columnHeights.max() ?? 0) - (subviews.isEmpty ? 0 : spacing), 0)
        return (frames, CGSize(width: width, height: contentHeight))
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
