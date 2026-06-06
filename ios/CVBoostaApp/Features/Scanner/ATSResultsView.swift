import SwiftUI
import SwiftData
import UIKit

struct ATSResultsView: View {
    @EnvironmentObject private var appRouter: AppRouter
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    let result: ResumeScanResult

    @State private var didPersistLatestScan = false
    @State private var animatedScore = 0
    @State private var revealHero = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                overviewCard
                recommendationsCard
                missingSkillsCard
                optimizedCVCard
                feedbackCard
                actionsCard
            }
            .padding(BoostaSpace.md)
        }
        .background(
            LinearGradient(
                colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Results")
        .onAppear {
            persistLatestScanIfNeeded()
            animateHeroScore()
        }
    }

    private func persistLatestScanIfNeeded() {
        guard !didPersistLatestScan else { return }
        didPersistLatestScan = true

        do {
            try LatestScanCacheStore.persist(result: result, in: modelContext)
        } catch {
            // Best-effort cache for companion features; ignore persistence failures.
        }
    }

    private var overviewCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(
                    title: result.resumeName,
                    subtitle: "\(result.targetRole) • \(result.experienceLevel) • \(result.targetMarket)"
                )

                HStack(alignment: .center, spacing: BoostaSpace.md) {
                    ScoreRing(score: animatedScore)
                        .frame(width: 122, height: 122)
                        .scaleEffect(revealHero ? 1 : 0.88)

                    VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                        Text(recruiterVisibilityTitle)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                        Text("\(animatedScore)/100")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(BoostaColor.primaryText)
                        Text(heroSubtitle)
                            .font(BoostaType.bodyStrong)
                            .foregroundStyle(heroTint)

                        if result.isDemo {
                            Text("Demo mode result")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.warning)
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BoostaSpace.sm) {
                    ResultInsightCard(title: "Recruiter visibility", value: recruiterVisibilityTitle, tint: heroTint)
                    ResultInsightCard(title: "Potential lift", value: potentialLiftLabel, tint: BoostaColor.accent)
                    ResultInsightCard(title: "Keyword gaps", value: "\(result.response.missingSkills.count)", tint: BoostaColor.warning)
                    ResultInsightCard(title: "Improvement state", value: readinessBadge, tint: BoostaColor.success)
                }

                Text(resultSummary)
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private var recommendationsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "AI improvements", subtitle: "Tap into the highest-impact fixes first")

                let items = subscriptionService.isPremium
                    ? result.response.recommendations.prefix(6)
                    : result.response.recommendations.prefix(3)

                if items.isEmpty {
                    Text("No recommendations returned for this scan.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                        HStack(alignment: .top, spacing: BoostaSpace.xs) {
                            Text("\(idx + 1).")
                                .font(BoostaType.bodyStrong)
                                .foregroundStyle(BoostaColor.accent)
                            Text(item)
                                .font(BoostaType.body)
                                .foregroundStyle(BoostaColor.secondaryText)
                        }
                    }
                }
            }
        }
    }

    private var missingSkillsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Keyword gaps", subtitle: "The terms that can improve recruiter visibility")

                let limit = subscriptionService.isPremium ? 18 : 10
                if result.response.missingSkills.isEmpty {
                    Text("No missing skills detected.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(Array(result.response.missingSkills.prefix(limit)), id: \.self) { keyword in
                            KeywordChip(text: keyword, status: .missing)
                        }
                    }
                }
            }
        }
    }

    private var optimizedCVCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Optimized preview", subtitle: "Sharper lines, fewer weak phrases, stronger ATS language")

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(previewBullets(from: result.response.optimizedCV), id: \.self) { line in
                        HStack(alignment: .top, spacing: BoostaSpace.xs) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(BoostaColor.success)
                                .padding(.top, 2)
                            Text(line)
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                                .textSelection(.enabled)
                        }
                    }
                }

                HStack(spacing: BoostaSpace.sm) {
                    SecondaryButton(title: "Copy Optimized") {
                        copyToClipboard(result.response.optimizedCV)
                        HapticsService.success()
                    }

                    SecondaryButton(title: "Open Tailoring") {
                        appRouter.open(.tailoring)
                    }
                }
            }
        }
    }

    private var feedbackCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Feedback")
                Text(result.response.feedback)
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
                    .textSelection(.enabled)
            }
        }
    }

    private var actionsCard: some View {
        VStack(spacing: BoostaSpace.sm) {
            PrimaryButton(title: "Improve This Resume") {
                appRouter.open(.tailoring)
            }

            SecondaryButton(title: "Save Report") {
                HapticsService.success()
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    private var recruiterVisibilityTitle: String {
        switch result.response.atsScore {
        case 85...100: return "High visibility"
        case 70...84: return "Moderate visibility"
        case 1...69: return "Low visibility"
        default: return "No visibility yet"
        }
    }

    private var heroSubtitle: String {
        switch result.response.atsScore {
        case 85...100: return "Your resume looks recruiter-ready."
        case 70...84: return "You’re close — a few fixes can raise response odds."
        case 1...69: return "Your resume may be filtered before review."
        default: return "Run a full scan to unlock recruiter visibility."
        }
    }

    private var heroTint: Color {
        switch result.response.atsScore {
        case 85...100: return BoostaColor.success
        case 70...84: return BoostaColor.warning
        default: return BoostaColor.danger
        }
    }

    private var potentialLiftLabel: String {
        let improved = max((result.response.matchAfter ?? result.response.atsScore) - result.response.atsScore, 0)
        return improved == 0 ? "Maintain" : "+\(improved) possible"
    }

    private var readinessBadge: String {
        if result.response.missingSkills.isEmpty { return "Well aligned" }
        if result.response.missingSkills.count <= 3 { return "Almost there" }
        return "Needs tailoring"
    }

    private var resultSummary: String {
        if let after = result.response.matchAfter, after > result.response.atsScore {
            return "CVBoosta found room to improve this version by \(after - result.response.atsScore) points with stronger ATS language and better role alignment."
        }
        return "Use tailoring to improve keyword targeting, recruiter readability, and role-specific impact."
    }

    private func previewBullets(from text: String) -> [String] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 30 }

        if !lines.isEmpty {
            return Array(lines.prefix(4))
        }

        return Array(
            text
                .components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count > 24 }
                .prefix(4)
        )
    }

    private func animateHeroScore() {
        animatedScore = 0
        revealHero = false

        Task { @MainActor in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                revealHero = true
            }

            for value in 0...result.response.atsScore {
                animatedScore = value
                try? await Task.sleep(for: .milliseconds(12))
            }
        }
    }
}

private struct ResultInsightCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
            Text(value)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(BoostaSpace.sm)
        .background(Color.white.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(BoostaColor.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
    }
}
