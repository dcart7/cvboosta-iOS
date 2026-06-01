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
    @State private var isOpeningStudio: Bool = false
    @State private var errorMessage: String?

    private let authenticatedClient = AuthenticatedAPIClient.shared

    private var latestPayload: LatestScanPayload? {
        guard let data = latestReports.first?.payloadJSON else { return nil }
        return try? JSONDecoder().decode(LatestScanPayload.self, from: data)
    }

    private var topKeywords: [String] {
        guard let payload = latestPayload else { return [] }
        let keywords = payload.response.keywordGaps
        let limit = subscriptionService.isPremium ? 12 : 6
        return Array(keywords.prefix(limit))
    }

    private var bulletPairs: [(original: String, improved: String)] {
        guard let payload = latestPayload else { return [] }
        return Array(zip(payload.response.weakBulletExamples, payload.response.rewriteSuggestions))
    }

    private var quickImprovements: [String] {
        guard let payload = latestPayload else { return [] }
        let fixes = payload.response.priorityFixes
        let limit = subscriptionService.isPremium ? 6 : 3
        return Array(fixes.prefix(limit))
    }

    private var topRisk: ATSFinding? {
        latestPayload?.response.findings.sorted(by: { $0.severity > $1.severity }).first
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
                            atsMatchPreviewCard(payload)
                            topMissingKeywordsCard(payload)
                            weakestSectionCard(payload)
                            atsRiskCard(payload)
                            quickImprovementsCard(payload)
                            optimizedBulletsCard(payload)
                        } else {
                            emptyStateCard
                        }

                        continueOnWebCard
                    }
                    .padding(BoostaSpace.md)
                }
            }
            .navigationTitle("Tailoring")
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
                    subtitle: "Quick, mobile-first improvements. Continue deep optimization on web."
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

                    SecondaryButton(title: "Re-run quick scan") {
                        HapticsService.impact(.light)
                        appRouter.open(.scanner)
                    }
                }
            }
        }
    }

    private func atsMatchPreviewCard(_ payload: LatestScanPayload) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(
                    title: "ATS Match Preview",
                    subtitle: "Based on your latest scan"
                )

                HStack(spacing: BoostaSpace.md) {
                    ScoreRing(score: payload.response.atsScore)
                        .frame(width: 108, height: 108)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(payload.resumeName)
                            .font(BoostaType.bodyStrong)
                        Text(payload.targetRole)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                        Text(payload.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                    metricRow(title: "Keyword coverage", value: payload.response.keywordCoverage)
                    metricRow(title: "Measurable impact", value: payload.response.measurableImpactRatio)
                    metricRow(title: "Recruiter signal", value: payload.response.recruiterSignalScore)
                }

                if payload.isDemo {
                    Text("Demo fallback result")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.warning)
                }
            }
        }
    }

    private func topMissingKeywordsCard(_ payload: LatestScanPayload) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Top Missing Keywords")

                if payload.response.keywordGaps.isEmpty {
                    Text("No major keyword gaps detected.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(topKeywords, id: \.self) { keyword in
                            KeywordChip(text: keyword, status: .missing)
                        }
                    }

                    if !subscriptionService.isPremium && payload.response.keywordGaps.count > topKeywords.count {
                        Text("Upgrade to see the full keyword map.")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.warning)
                    }
                }
            }
        }
    }

    private func weakestSectionCard(_ payload: LatestScanPayload) -> some View {
        let metrics: [(String, Double, String)] = [
            ("Keywords", payload.response.keywordCoverage, "Add missing role terms to summary + top experience bullets."),
            ("Impact", payload.response.measurableImpactRatio, "Add numbers, scope, and outcomes to your strongest bullets."),
            ("Readability", payload.response.readabilityScore, "Shorten sentences and make bullets more scannable."),
            ("Role Match", payload.response.recruiterSignalScore, "Mirror the job’s core responsibilities and tools."),
        ]

        let weakest = metrics.min(by: { $0.1 < $1.1 })

        return GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Weakest Resume Section")

                if let weakest {
                    HStack {
                        Text(weakest.0)
                            .font(BoostaType.bodyStrong)
                        Spacer()
                        Text("\(Int(weakest.1 * 100))")
                            .font(BoostaType.bodyStrong)
                            .foregroundStyle(BoostaColor.warning)
                    }

                    Text(weakest.2)
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    Text("Run a scan to identify your weakest area.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
    }

    private func atsRiskCard(_ payload: LatestScanPayload) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "ATS Risk Detected")

                if let risk = topRisk {
                    HStack(alignment: .top, spacing: BoostaSpace.xs) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundStyle(BoostaColor.warning)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(risk.message)
                                .font(BoostaType.bodyStrong)
                            Text(risk.suggestion)
                                .font(BoostaType.body)
                                .foregroundStyle(BoostaColor.secondaryText)
                        }
                    }
                } else {
                    Text("No high-severity ATS risks flagged in this scan.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
    }

    private func quickImprovementsCard(_ payload: LatestScanPayload) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Quick Improvements")

                if quickImprovements.isEmpty {
                    Text("No quick wins found. Try scanning with a job description for higher precision.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    ForEach(Array(quickImprovements.enumerated()), id: \.offset) { idx, item in
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

    private func optimizedBulletsCard(_ payload: LatestScanPayload) -> some View {
        let limit = subscriptionService.isPremium ? 4 : 2
        let pairs = Array(bulletPairs.prefix(limit))

        return GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "Optimized Bullet Previews",
                    subtitle: "One-tap copy or save for later"
                )

                if pairs.isEmpty {
                    Text("Scan a resume to get rewrite previews.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weak")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                            Text("\"\(pair.original)\"")
                                .font(BoostaType.body)

                            Text("Optimized")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)

                            HStack(alignment: .top, spacing: BoostaSpace.sm) {
                                Text("\"\(pair.improved)\"")
                                    .font(BoostaType.bodyStrong)

                                Spacer(minLength: 0)

                                Button {
                                    copyToClipboard(pair.improved)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundStyle(BoostaColor.accent)
                                }
                                .accessibilityLabel("Copy optimized bullet")

                                Button {
                                    saveSuggestion(text: pair.improved, payload: payload)
                                } label: {
                                    Image(systemName: "bookmark")
                                        .foregroundStyle(BoostaColor.secondaryText)
                                }
                                .accessibilityLabel("Save suggestion")
                            }

                            Divider()
                                .opacity(0.35)
                        }
                    }

                    if !subscriptionService.isPremium && bulletPairs.count > pairs.count {
                        Text("Upgrade to unlock more rewrite previews.")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.warning)
                    }
                }

                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
            }
        }
    }

    private var emptyStateCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "No scan yet",
                    subtitle: "Run a quick ATS scan to unlock tailoring previews."
                )

                PrimaryButton(title: "Go to Scanner") {
                    appRouter.open(.scanner)
                }
            }
        }
    }

    private var continueOnWebCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "Continue Deep Optimization",
                    subtitle: "Open the full CVBoosta Studio workspace on web."
                )

                PrimaryButton(
                    title: isOpeningStudio ? "Opening..." : "Continue in CVBoosta Studio",
                    isLoading: isOpeningStudio,
                    isDisabled: isOpeningStudio
                ) {
                    Task { await openStudio() }
                }

                Text("Mobile stays lightweight by design: previews + quick wins here, power tools on web.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private func metricRow(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
            ProgressView(value: min(max(value, 0), 1))
                .tint(BoostaColor.accent)
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

    private struct WebContinueRequest: Encodable {
        let intent: String
        let context: String?
    }

    private struct WebContinueResponse: Decodable {
        let url: URL
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

    private func openStudio() async {
        isOpeningStudio = true
        defer { isOpeningStudio = false }

        do {
            // Optional backend support: returns a short-lived URL that sets a web session and deep-links.
            let response: WebContinueResponse = try await authenticatedClient.postJSON(
                path: "/auth/web-continue",
                body: WebContinueRequest(intent: "tailoring", context: "preview")
            )
            openURL(response.url)
        } catch {
            openURL(fallbackStudioURL())
        }
    }
}

#Preview {
    TailoringPreviewView()
        .environmentObject(AppRouter())
        .environmentObject(AuthViewModel())
        .modelContainer(PreviewModelContainer.shared)
}
