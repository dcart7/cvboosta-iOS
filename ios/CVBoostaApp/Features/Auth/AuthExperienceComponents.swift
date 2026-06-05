import SwiftUI

struct AuthBackgroundView: View {
    var body: some View {
        ZStack {
            BoostaColor.pageGradient
                .ignoresSafeArea()

            Circle()
                .fill(BoostaColor.pageGlow.opacity(0.28))
                .frame(width: 340, height: 340)
                .blur(radius: 18)
                .offset(x: -140, y: -280)

            Circle()
                .fill(BoostaColor.accentSecondary.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 18)
                .offset(x: 170, y: 220)

            Circle()
                .fill(BoostaColor.accent.opacity(0.15))
                .frame(width: 220, height: 220)
                .blur(radius: 26)
                .offset(x: 120, y: -120)
        }
    }
}

struct BrandMarkView: View {
    var size: CGFloat = 76
    var glow: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .fill(BoostaColor.pageGlow.opacity(0.18))
                .frame(width: size * 1.08, height: size * 1.08)
                .blur(radius: glow ? 12 : 0)

            BoostaColor.auroraGradient
                .frame(width: size, height: size)
                .mask(
                    Image("BrandMark")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .compositingGroup()
                        .colorInvert()
                        .luminanceToAlpha()
                )
        }
        .shadow(color: glow ? BoostaColor.accent.opacity(0.22) : .clear, radius: 22, x: 0, y: 10)
    }
}

struct AuthHeadlineBlock: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.xs) {
            Text(eyebrow.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(BoostaColor.accentSecondary)

            Text(title)
                .font(BoostaType.hero)
                .foregroundStyle(BoostaColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(BoostaType.body)
                .foregroundStyle(BoostaColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AuthStatPill: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(BoostaColor.primaryText)
            Text(detail)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BoostaSpace.sm)
        .padding(.vertical, BoostaSpace.sm)
        .background(BoostaColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(BoostaColor.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
    }
}

struct AuthProductPreviewCard: View {
    var body: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                HStack(alignment: .center, spacing: BoostaSpace.md) {
                    ScoreRing(score: 84, lineWidth: 10)
                        .frame(width: 82, height: 82)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ATS score preview")
                            .font(BoostaType.bodyStrong)
                            .foregroundStyle(BoostaColor.primaryText)
                        Text("Keyword gaps detected and optimized per job.")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }

                HStack(spacing: 8) {
                    KeywordChip(text: "SQL", status: .present)
                    KeywordChip(text: "Kubernetes", status: .weak)
                    KeywordChip(text: "Leadership", status: .missing)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Bullet rewrite")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Before")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(BoostaColor.tertiaryText)
                        Text("Worked on backend systems and team support.")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                            .strikethrough(false)
                    }
                    .padding(.horizontal, BoostaSpace.sm)
                    .padding(.vertical, 10)
                    .background(BoostaColor.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("After")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(BoostaColor.accentSecondary)
                        Text("Improved API latency by 32% and shipped ATS-aligned resume bullets for backend roles.")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.primaryText)
                    }
                    .padding(.horizontal, BoostaSpace.sm)
                    .padding(.vertical, 10)
                    .background(BoostaColor.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                            .stroke(BoostaColor.glassStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    previewRow(title: "More interviews", value: "+42%")
                    previewRow(title: "ATS optimized", value: "2 min")
                    previewRow(title: "Applicants using CVBoosta", value: "1,200+")
                }
            }
        }
    }

    private func previewRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
            Spacer()
            Text(value)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
        }
        .padding(.vertical, 2)
    }
}

struct AuthTrustRow: View {
    var body: some View {
        HStack(spacing: BoostaSpace.sm) {
            trustItem(icon: "lock.shield", title: "Private by design")
            trustItem(icon: "doc.text.magnifyingglass", title: "Secure resume processing")
        }
    }

    private func trustItem(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BoostaColor.accentSecondary)
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
        }
    }
}

struct AuthSocialProofRow: View {
    var body: some View {
        HStack(spacing: 8) {
            proofChip("1,200+ applicants")
            proofChip("ATS optimized in 2 min")
        }
    }

    private func proofChip(_ text: String) -> some View {
        Text(text)
            .font(BoostaType.caption)
            .foregroundStyle(BoostaColor.primaryText)
            .padding(.horizontal, BoostaSpace.sm)
            .padding(.vertical, 8)
            .background(BoostaColor.surface)
            .overlay(
                Capsule()
                    .stroke(BoostaColor.glassStroke, lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

struct AuthPrimaryNavigationButton<Destination: View>: View {
    let title: String
    let destination: () -> Destination

    init(title: String, @ViewBuilder destination: @escaping () -> Destination) {
        self.title = title
        self.destination = destination
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: BoostaSpace.xs) {
                Text(title)
                    .font(BoostaType.bodyStrong)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                    .fill(BoostaColor.auroraGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: BoostaColor.accent.opacity(0.24), radius: 18, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }
}

struct AuthSecondaryNavigationButton<Destination: View>: View {
    let title: String
    let systemImage: String
    let destination: () -> Destination

    init(title: String, systemImage: String, @ViewBuilder destination: @escaping () -> Destination) {
        self.title = title
        self.systemImage = systemImage
        self.destination = destination
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Text(title)
                    .font(BoostaType.bodyStrong)
                Spacer()
                Image(systemName: systemImage)
            }
            .foregroundStyle(BoostaColor.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, BoostaSpace.md)
            .padding(.vertical, 14)
            .background(BoostaColor.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                    .stroke(BoostaColor.glassStrongStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
