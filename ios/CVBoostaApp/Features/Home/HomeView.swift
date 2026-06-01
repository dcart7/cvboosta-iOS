import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: BoostaSpace.md) {
                        heroCard
                            .staggered(index: 0)

                        insightsRow
                            .staggered(index: 1)

                        GlassCard {
                            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                                Text("Resume Weaknesses")
                                    .font(BoostaType.section)
                                weakness("Low measurable outcomes in 4 bullets", score: "High")
                                weakness("Missing role terms: API gateway, CI/CD, observability", score: "High")
                                weakness("Summary too generic for Product roles", score: "Medium")
                            }
                        }
                        .staggered(index: 2)

                        GlassCard {
                            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                                Text("Today")
                                    .font(BoostaType.section)
                                Text("3 applications sent. 1 interview tomorrow at 13:00.")
                                    .font(BoostaType.body)
                                    .foregroundStyle(BoostaColor.secondaryText)
                            }
                        }
                        .staggered(index: 3)
                    }
                    .padding(BoostaSpace.md)
                }
            }
            .navigationTitle("CVBoosta")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Pro") {
                        PaywallView()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await authViewModel.logout()
                        }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityLabel("Log out")
                }
            }
        }
    }

    private var heroCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                Text("Career Command Center")
                    .font(BoostaType.title)
                    .foregroundStyle(BoostaColor.primaryText)

                HStack(spacing: BoostaSpace.sm) {
                    MetricPill(title: "ATS Score", value: "78", color: BoostaColor.success)
                    MetricPill(title: "Streak", value: "11 days", color: BoostaColor.accent)
                    MetricPill(title: "Interviews", value: "2 this week", color: BoostaColor.warning)
                }

                Text("Your signal is improving. Tailor 2 more role-specific bullets to cross ATS 82.")
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private var insightsRow: some View {
        HStack(spacing: BoostaSpace.md) {
            GlassCard {
                VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                    Text("Role Match")
                        .font(BoostaType.caption)
                    Text("Backend Developer")
                        .font(BoostaType.bodyStrong)
                    Text("86%")
                        .font(BoostaType.section)
                        .foregroundStyle(BoostaColor.success)
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                    Text("Next Interview")
                        .font(BoostaType.caption)
                    Text("Tomorrow")
                        .font(BoostaType.bodyStrong)
                    Text("13:00")
                        .font(BoostaType.section)
                        .foregroundStyle(BoostaColor.accent)
                }
            }
        }
    }

    private func weakness(_ message: String, score: String) -> some View {
        HStack {
            Text(message)
                .font(BoostaType.body)
                .foregroundStyle(BoostaColor.secondaryText)
            Spacer()
            Text(score)
                .font(BoostaType.caption)
                .padding(.horizontal, BoostaSpace.sm)
                .padding(.vertical, BoostaSpace.xs)
                .background(Color.white.opacity(0.45))
                .clipShape(Capsule())
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
