import SwiftUI

struct ATSResultsView: View {
    let result: ResumeScanResult
    @State private var animateScore = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                scoreCard
                findingsCard
                priorityFixesCard
                keywordGapCard
                weakBulletsCard
                suggestionsCard

                NavigationLink {
                    PaywallView()
                } label: {
                    Text("Boost fully with CVBoosta")
                        .font(BoostaType.bodyStrong)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(BoostaColor.accent)
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
        .navigationTitle("ATS Results")
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) {
                animateScore = true
            }
        }
    }

    private var findingsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                Text("Issues")
                    .font(BoostaType.section)

                if result.response.findings.isEmpty {
                    Text("No critical issues detected.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    ForEach(result.response.findings) { finding in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(finding.message)
                                .font(BoostaType.bodyStrong)
                            Text(finding.suggestion)
                                .font(BoostaType.body)
                                .foregroundStyle(BoostaColor.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var scoreCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                HStack {
                    Text("ATS Score")
                        .font(BoostaType.section)

                    if result.isDemo {
                        Text("DEMO")
                            .font(BoostaType.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, BoostaSpace.sm)
                            .padding(.vertical, BoostaSpace.xxs)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Spacer()
                }

                HStack(spacing: BoostaSpace.lg) {
                    ScoreRingView(score: result.response.atsScore, progress: animateScore ? 1 : 0)
                        .frame(width: 120, height: 120)

                    VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                        Text("Keyword coverage: \(Int(result.response.keywordCoverage * 100))%")
                            .font(BoostaType.body)
                        Text("Signal quality: \(Int(result.response.recruiterSignalScore * 100))%")
                            .font(BoostaType.body)
                        Text("Impact ratio: \(Int(result.response.measurableImpactRatio * 100))%")
                            .font(BoostaType.body)
                    }
                    .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
    }

    private var priorityFixesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                Text("Priority Fixes")
                    .font(BoostaType.section)

                ForEach(Array(result.response.priorityFixes.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: BoostaSpace.sm) {
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

    private var keywordGapCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                Text("Keyword Gaps")
                    .font(BoostaType.section)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(result.response.keywordGaps.prefix(12), id: \.self) { keyword in
                        Text(keyword)
                            .font(BoostaType.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.55))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var weakBulletsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                Text("Weak Bullet Examples")
                    .font(BoostaType.section)

                if result.response.weakBulletExamples.isEmpty {
                    Text("No weak bullets detected in this scan.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    ForEach(result.response.weakBulletExamples, id: \.self) { bullet in
                        Text("• \(bullet)")
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }
            }
        }
    }

    private var suggestionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                Text("Rewrite Suggestions")
                    .font(BoostaType.section)

                ForEach(result.response.rewriteSuggestions, id: \.self) { suggestion in
                    Text("• \(suggestion)")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
    }
}

private struct ScoreRingView: View {
    let score: Int
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.36), lineWidth: 12)

            Circle()
                .trim(from: 0, to: progress * min(Double(score) / 100, 1.0))
                .stroke(
                    AngularGradient(
                        colors: [Color.blue, Color.cyan, Color.green],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("/100")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }
}
