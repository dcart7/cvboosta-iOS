import SwiftUI
import SwiftData

struct ATSResultsView: View {
    @EnvironmentObject private var appRouter: AppRouter
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    let result: ResumeScanResult

    @State private var didPersistLatestScan = false

    private struct CategoryScore: Identifiable {
        let id = UUID()
        let title: String
        let score: Int
        let explanation: String

        var status: String {
            switch score {
            case 80...100: return "Good"
            case 60...79: return "Needs Work"
            default: return "Critical"
            }
        }

        var color: Color {
            switch status {
            case "Good": return BoostaColor.success
            case "Needs Work": return BoostaColor.warning
            default: return BoostaColor.danger
            }
        }
    }

    private var categories: [CategoryScore] {
        [
            CategoryScore(
                title: "Structure",
                score: Int(result.response.readabilityScore * 100),
                explanation: "Section clarity and ATS section parsing quality."
            ),
            CategoryScore(
                title: "Keywords",
                score: Int(result.response.keywordCoverage * 100),
                explanation: "Coverage of expected role-specific terms."
            ),
            CategoryScore(
                title: "Readability",
                score: Int(result.response.readabilityScore * 100),
                explanation: "Sentence quality and scannability."
            ),
            CategoryScore(
                title: "Impact",
                score: Int(result.response.measurableImpactRatio * 100),
                explanation: "How many bullets show measurable outcomes."
            ),
            CategoryScore(
                title: "Role Match",
                score: Int(result.response.recruiterSignalScore * 100),
                explanation: "How well the resume matches target role signals."
            ),
        ]
    }

    private var weakBulletPairs: [(original: String, improved: String)] {
        zip(result.response.weakBulletExamples, result.response.rewriteSuggestions).map { ($0.0, $0.1) }
    }

    private var formattingChecks: [(String, Bool)] {
        [
            ("File parsing status", result.response.readabilityScore >= 0.55),
            ("Section detection", result.response.readabilityScore >= 0.65),
            ("Bullet consistency", result.response.measurableImpactRatio >= 0.45),
            ("Contact information detection", result.response.atsScore >= 60),
        ]
    }

    private var recruiterSignals: [String] {
        var signals = result.response.findings
            .sorted(by: { $0.severity > $1.severity })
            .prefix(3)
            .map(\.message)

        if signals.isEmpty {
            signals = [
                "Add measurable achievements",
                "Clarify technical impact",
                "Use more role-specific terminology",
            ]
        }

        return signals
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                overviewCard
                scoreCategoriesCard
                priorityFixesCard
                keywordGapCard
                weakBulletsCard
                formattingCard
                recruiterSignalCard
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

                HStack(spacing: BoostaSpace.md) {
                    ScoreRing(score: result.response.atsScore)
                        .frame(width: 116, height: 116)

                    VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                        Text("Your latest resume score")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                        Text("ATS compatibility: \(result.response.atsScore)/100")
                            .font(BoostaType.bodyStrong)
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

    private var scoreCategoriesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Score categories")
                ForEach(categories) { item in
                    VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                        HStack {
                            Text(item.title)
                                .font(BoostaType.bodyStrong)
                            Spacer()
                            Text("\(item.score)")
                                .font(BoostaType.bodyStrong)
                            Text(item.status)
                                .font(BoostaType.caption)
                                .padding(.horizontal, BoostaSpace.xs)
                                .padding(.vertical, BoostaSpace.xxs)
                                .background(item.color.opacity(0.2))
                                .foregroundStyle(item.color)
                                .clipShape(Capsule())
                        }
                        Text(item.explanation)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }
            }
        }
    }

    private var priorityFixesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Priority Fixes")

                let fixes = subscriptionService.isPremium ? result.response.priorityFixes.prefix(5) : result.response.priorityFixes.prefix(3)
                ForEach(Array(fixes.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: BoostaSpace.xs) {
                        Text("\(idx + 1).")
                            .font(BoostaType.bodyStrong)
                            .foregroundStyle(BoostaColor.accent)
                        Text(item)
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }

                if !subscriptionService.isPremium {
                    Text("Deep analysis is available in Premium.")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.warning)
                }
            }
        }
    }

    private var keywordGapCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Missing Keywords")

                if result.response.keywordGaps.isEmpty {
                    Text("No major keyword gaps detected.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(Array(result.response.keywordGaps.prefix(12)), id: \.self) { keyword in
                            KeywordChip(text: keyword, status: .missing)
                        }
                    }
                }
            }
        }
    }

    private var weakBulletsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Weak Bullets")

                if weakBulletPairs.isEmpty {
                    Text("No weak bullets detected in this scan.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    ForEach(Array(weakBulletPairs.prefix(subscriptionService.isPremium ? 5 : 3).enumerated()), id: \.offset) { _, pair in
                        VStack(alignment: .leading, spacing: BoostaSpace.xxs) {
                            Text("Original")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                            Text("\"\(pair.original)\"")
                                .font(BoostaType.body)

                            Text("Improved")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                            Text("\"\(pair.improved)\"")
                                .font(BoostaType.bodyStrong)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }

    private var formattingCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "ATS Formatting")
                ForEach(Array(formattingChecks.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Image(systemName: item.1 ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(item.1 ? BoostaColor.success : BoostaColor.warning)
                        Text(item.0)
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }
            }
        }
    }

    private var recruiterSignalCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Recruiter Signal")
                ForEach(recruiterSignals, id: \.self) { signal in
                    Text("• \(signal)")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
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
}
