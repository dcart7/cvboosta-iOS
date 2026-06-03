import SwiftUI
import SwiftData
import UIKit

struct ATSResultsView: View {
    @EnvironmentObject private var appRouter: AppRouter
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    let result: ResumeScanResult

    @State private var didPersistLatestScan = false

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
        }
    }

    private func persistLatestScanIfNeeded() {
        guard !didPersistLatestScan else { return }
        didPersistLatestScan = true

        do {
            let payload = LatestScanPayload(from: result)
            let data = try JSONEncoder().encode(payload)

            let descriptor = FetchDescriptor<LatestScanReport>(
                predicate: #Predicate { $0.id == "latest" }
            )
            if let existing = try modelContext.fetch(descriptor).first {
                existing.updatedAt = payload.updatedAt
                existing.payloadJSON = data
            } else {
                modelContext.insert(
                    LatestScanReport(
                        updatedAt: payload.updatedAt,
                        payloadJSON: data
                    )
                )
            }

            try modelContext.save()
        } catch {
            // Best-effort cache for companion features; ignore persistence failures.
        }
    }

    private var overviewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(
                    title: result.resumeName,
                    subtitle: "\(result.targetRole) • \(result.experienceLevel) • \(result.targetMarket)"
                )

                HStack(alignment: .top, spacing: BoostaSpace.md) {
                    ScoreRing(score: result.response.atsScore)
                        .frame(width: 116, height: 116)

                    VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                        Text("Baseline match score")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                        Text("\(result.response.atsScore)/100")
                            .font(BoostaType.bodyStrong)

                        if let after = result.response.matchAfter, after != result.response.atsScore {
                            Text("After optimization: \(after)/100")
                                .font(BoostaType.caption)
                                .foregroundStyle(after > result.response.atsScore ? BoostaColor.success : BoostaColor.secondaryText)
                        }
                        if result.isDemo {
                            Text("Demo mode result")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.warning)
                        }
                    }
                }
            }
        }
    }

    private var recommendationsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Recommendations")

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
                SectionHeader(title: "Missing skills / keywords")

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
                SectionHeader(title: "Optimized resume (preview)", subtitle: "Generated by CVBoosta backend")

                Text(result.response.optimizedCV)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
                    .textSelection(.enabled)
                    .lineLimit(18)

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
}
