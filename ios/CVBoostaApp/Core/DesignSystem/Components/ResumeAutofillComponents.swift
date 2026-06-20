import SwiftUI

struct ResumeAutofillPromptCard: View {
    let title: String
    let subtitle: String
    let primaryTitle: String
    let secondaryTitle: String
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: title, subtitle: subtitle)

                HStack(spacing: BoostaSpace.sm) {
                    PrimaryButton(title: primaryTitle, action: primaryAction)
                    SecondaryButton(title: secondaryTitle, action: secondaryAction)
                }
            }
        }
    }
}

struct ResumeRepeatedUploadSuggestionCard: View {
    let fileName: String
    let uploadCount: Int
    let makePrimary: () -> Void
    let dismiss: () -> Void

    var body: some View {
        GlassCard(padding: BoostaSpace.sm) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Make this your primary resume?", systemImage: "sparkles.rectangle.stack")
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.primaryText)

                Text("You have uploaded \(fileName) \(uploadCount)x. Save it as primary and reuse it across Scanner, Tailoring, and quick flows.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: BoostaSpace.sm) {
                    PrimaryButton(title: "Make Primary", action: makePrimary)
                    SecondaryButton(title: "Not Now", action: dismiss)
                }
            }
        }
    }
}

struct ResumeFlowBubble: View {
    let message: String

    var body: some View {
        GlassCard(padding: BoostaSpace.sm) {
            HStack(spacing: BoostaSpace.xs) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(BoostaColor.warning)
                Text(message)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }
}

struct PrimaryResumeBadge: View {
    var body: some View {
        Text("Primary")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(BoostaColor.success)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(BoostaColor.success.opacity(0.12))
            .clipShape(Capsule())
    }
}
