import SwiftUI
import SwiftData
import UIKit

/// Lightweight companion Tailoring experience.
/// Full tailoring, editing, and exports live on the web.
struct TailoringPreviewView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appRouter: AppRouter
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    @Query(filter: #Predicate<LatestScanReport> { $0.id == "latest" })
    private var latestReports: [LatestScanReport]

    @Query(sort: \SavedTailoringSuggestion.createdAt, order: .reverse)
    private var savedSuggestions: [SavedTailoringSuggestion]

    @State private var toastMessage: String?
    @State private var errorMessage: String?

    private var latestPayload: LatestScanPayload? {
        guard let data = latestReports.first?.payloadJSON else { return nil }
        return try? JSONDecoder().decode(LatestScanPayload.self, from: data)
    }

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
                    VStack(spacing: BoostaSpace.md) {
                        headerCard

                        if let payload = latestPayload {
                            matchCard(payload)
                            missingSkillsCard(payload)
                            recommendationsCard(payload)
                            optimizedPreviewCard(payload)
                        } else {
                            emptyStateCard
                        }

                        continueOnWebCard
                    }
                    .padding(BoostaSpace.md)
                }
            }
            .navigationTitle("Tailoring")
            .overlay(alignment: .top) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                        .padding(.horizontal, BoostaSpace.md)
                        .padding(.top, BoostaSpace.sm)
                }
            }
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                toastView(message: toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation(BoostaMotion.smooth) {
                                self.toastMessage = nil
                            }
                        }
                    }
                    .padding(.horizontal, BoostaSpace.md)
                    .padding(.top, 10)
            }
        }
    }

    private var headerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "Tailoring Preview",
                    subtitle: "Quick improvements. Continue deep optimization on web."
                )

                HStack(alignment: .top, spacing: BoostaSpace.sm) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Saved suggestions: \(savedSuggestions.count)")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)

                        Text(subscriptionService.isPremium ? "Premium" : "Free")
                            .font(BoostaType.bodyStrong)
                            .foregroundStyle(subscriptionService.isPremium ? BoostaColor.success : BoostaColor.secondaryText)
                    }

                    Spacer()

                    Button {
                        openURL(fallbackStudioURL())
                    } label: {
                        Label("Studio", systemImage: "safari")
                            .font(BoostaType.bodyStrong)
                            .foregroundStyle(BoostaColor.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func matchCard(_ payload: LatestScanPayload) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "Latest optimization",
                    subtitle: payload.updatedAt.formatted(date: .abbreviated, time: .shortened)
                )

                HStack(spacing: BoostaSpace.md) {
                    ScoreRing(score: payload.response.atsScore)
                        .frame(width: 94, height: 94)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(payload.resumeName)
                            .font(BoostaType.bodyStrong)
                        Text(payload.targetRole)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)

                        if let after = payload.response.matchAfter, after != payload.response.atsScore {
                            Text("After optimization: \(after)/100")
                                .font(BoostaType.caption)
                                .foregroundStyle(after > payload.response.atsScore ? BoostaColor.success : BoostaColor.secondaryText)
                        }
                    }
                }

                if payload.isDemo {
                    Text("Demo fallback result")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.warning)
                }
            }
        }
    }

    private func missingSkillsCard(_ payload: LatestScanPayload) -> some View {
        let limit = subscriptionService.isPremium ? 14 : 8

        return GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Missing skills / keywords")

                if payload.response.missingSkills.isEmpty {
                    Text("No missing skills detected.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(Array(payload.response.missingSkills.prefix(limit)), id: \.self) { keyword in
                            KeywordChip(text: keyword, status: .missing)
                        }
                    }
                }
            }
        }
    }

    private func recommendationsCard(_ payload: LatestScanPayload) -> some View {
        let limit = subscriptionService.isPremium ? 6 : 3
        let items = Array(payload.response.recommendations.prefix(limit))

        return GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Recommendations")

                if items.isEmpty {
                    Text("No recommendations returned for this optimization.")
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

    private func optimizedPreviewCard(_ payload: LatestScanPayload) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Optimized resume (preview)")

                Text(payload.response.optimizedCV)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
                    .textSelection(.enabled)
                    .lineLimit(16)

                HStack(spacing: BoostaSpace.sm) {
                    SecondaryButton(title: "Copy") {
                        copyToClipboard(payload.response.optimizedCV)
                    }

                    SecondaryButton(title: "Save") {
                        saveSuggestion(text: payload.response.optimizedCV, payload: payload)
                    }
                }

                if !payload.response.addedKeywords.isEmpty {
                    let limit = subscriptionService.isPremium ? 10 : 5
                    Text("Added keywords: \(Array(payload.response.addedKeywords.prefix(limit)).joined(separator: ", "))")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
    }

    private var emptyStateCard: some View {
        GlassCard {
            EmptyStateView(
                title: "No optimization yet",
                message: "Run one scan to populate Tailoring with an optimized ATS-friendly version.",
                actionTitle: "Go to Scanner"
            ) {
                appRouter.open(.scanner)
            }
        }
    }

    private var continueOnWebCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "Continue on CVBoosta Studio",
                    subtitle: "Deep resume editing, exports, and advanced AI are on web."
                )

                PrimaryButton(title: "Open Studio") {
                    openURL(fallbackStudioURL())
                }

                Text("Tip: Use Tailoring on iPad for side-by-side resume comparison.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private func toastView(message: String) -> some View {
        GlassCard(padding: BoostaSpace.sm) {
            HStack(spacing: BoostaSpace.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(BoostaColor.success)
                Text(message)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.primaryText)
                Spacer(minLength: 0)
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        HapticsService.success()
        withAnimation(BoostaMotion.smooth) {
            toastMessage = "Copied"
        }
    }

    private func saveSuggestion(text: String, payload: LatestScanPayload) {
        errorMessage = nil

        modelContext.insert(
            SavedTailoringSuggestion(
                resumeName: payload.resumeName,
                roleTitle: payload.targetRole,
                text: text
            )
        )

        do {
            try modelContext.save()
            withAnimation(BoostaMotion.smooth) {
                toastMessage = "Saved"
            }
        } catch {
            errorMessage = "Could not save suggestion."
        }
    }

    private func fallbackStudioURL() -> URL {
        var components = URLComponents(url: AppEnvironment.webBaseURL, resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = [
            URLQueryItem(name: "from", value: "ios"),
            URLQueryItem(name: "intent", value: "tailoring_preview"),
        ]

        if let payload = latestPayload {
            items.append(URLQueryItem(name: "role", value: payload.targetRole))
        }

        components?.queryItems = items
        return components?.url ?? AppEnvironment.webBaseURL
    }
}

#Preview {
    TailoringPreviewView()
        .environmentObject(AppRouter())
        .environmentObject(AuthViewModel())
        .modelContainer(PreviewModelContainer.shared)
}
