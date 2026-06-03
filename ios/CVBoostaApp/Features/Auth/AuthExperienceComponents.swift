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
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(BoostaColor.surfaceElevated)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                        .stroke(BoostaColor.glassStrongStroke, lineWidth: 1)
                )

            Image("BrandMark")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(size * 0.12)
                .frame(width: size, height: size)
        }
        .shadow(color: glow ? BoostaColor.accent.opacity(0.22) : .clear, radius: 22, x: 0, y: 10)
    }
}

struct AuthHeadlineBlock: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.sm) {
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

struct AuthFeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: BoostaSpace.sm) {
            ZStack {
                Circle()
                    .fill(BoostaColor.surfaceElevated)
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BoostaColor.accentSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.primaryText)
                Text(detail)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }
}

struct AuthStoryCard: View {
    let title: String
    let steps: [String]

    var body: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                Text(title)
                    .font(BoostaType.section)
                    .foregroundStyle(BoostaColor.primaryText)

                VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .center, spacing: BoostaSpace.sm) {
                            ZStack {
                                Circle()
                                    .fill(index == 0 ? BoostaColor.auroraGradient : LinearGradient(colors: [BoostaColor.surfaceElevated, BoostaColor.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 28, height: 28)
                                Text("\(index + 1)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }

                            Text(step)
                                .font(BoostaType.body)
                                .foregroundStyle(BoostaColor.secondaryText)
                        }
                        .staggered(index: index)
                    }
                }
            }
        }
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
