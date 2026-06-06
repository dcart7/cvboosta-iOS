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
                            tailoringDiffCard(payload)
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
                    title: "AI Tailoring",
                    subtitle: "Fast rewrite preview on iPhone. Deep editing stays on web."
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

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(previewBullets(from: payload.response.optimizedCV), id: \.self) { bullet in
                        HStack(alignment: .top, spacing: BoostaSpace.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(BoostaColor.success)
                                .padding(.top, 2)
                            Text(bullet)
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                                .textSelection(.enabled)
                        }
                    }
                }

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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Inserted keywords")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                            ForEach(Array(payload.response.addedKeywords.prefix(limit)), id: \.self) { keyword in
                                KeywordChip(text: keyword, status: .present)
                            }
                        }
                    }
                }
            }
        }
    }

    private func tailoringDiffCard(_ payload: LatestScanPayload) -> some View {
        let before = previewBullets(from: payload.response.originalCVText)
        let after = previewBullets(from: payload.response.optimizedCV)
        let weakPhrases = weakPhrases(in: payload.response.originalCVText)

        return GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "What changed", subtitle: "See AI value before you open Studio")

                ForEach(Array(zip(before.indices, before)).prefix(2), id: \.0) { pair in
                    let index = pair.0
                    let oldLine = pair.1
                    VStack(alignment: .leading, spacing: 8) {
                        TailoringDiffLine(label: "Before", text: oldLine, tint: BoostaColor.secondaryText, symbol: "minus.circle.fill")

                        if after.indices.contains(index) {
                            TailoringDiffLine(label: "After", text: after[index], tint: BoostaColor.success, symbol: "plus.circle.fill")
                        }
                    }
                }

                if !payload.response.addedKeywords.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Boosted with ATS keywords")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                            ForEach(Array(payload.response.addedKeywords.prefix(6)), id: \.self) { keyword in
                                KeywordChip(text: keyword, status: .present)
                            }
                        }
                    }
                }

                if !weakPhrases.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weak phrases replaced")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                            ForEach(weakPhrases, id: \.self) { phrase in
                                KeywordChip(text: phrase, status: .missing)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyStateCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Before → after preview", subtitle: "What CVBoosta improves")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Before")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                    Text("Worked on backend services and APIs.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                        .padding(.horizontal, BoostaSpace.sm)
                        .padding(.vertical, 10)
                        .background(BoostaColor.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("After")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.accentSecondary)
                    Text("Built scalable backend APIs that reduced response times and improved role-specific keyword match.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.primaryText)
                        .padding(.horizontal, BoostaSpace.sm)
                        .padding(.vertical, 10)
                        .background(BoostaColor.surfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                                .stroke(BoostaColor.glassStroke, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
                }

                SecondaryButton(title: "Open Scanner") {
                    appRouter.open(.scanner)
                }
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

    private func previewBullets(from text: String) -> [String] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 30 }

        if !lines.isEmpty {
            return Array(lines.prefix(3))
        }

        let sentences = text
            .components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 24 }

        return Array(sentences.prefix(3))
    }

    private func weakPhrases(in text: String) -> [String] {
        let lowered = text.lowercased()
        let candidates = [
            "worked on",
            "responsible for",
            "helped with",
            "involved in",
            "participated in"
        ]
        return candidates.filter { lowered.contains($0) }
    }
}

private struct TailoringDiffLine: View {
    let label: String
    let text: String
    let tint: Color
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(BoostaType.caption)
                .foregroundStyle(tint)

            HStack(alignment: .top, spacing: BoostaSpace.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                    .padding(.top, 2)
                Text(text)
                    .font(BoostaType.body)
                    .foregroundStyle(label == "After" ? BoostaColor.primaryText : BoostaColor.secondaryText)
            }
            .padding(.horizontal, BoostaSpace.sm)
            .padding(.vertical, 10)
            .background(label == "After" ? BoostaColor.surfaceElevated : BoostaColor.surfaceMuted)
            .overlay(
                RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                    .stroke(label == "After" ? BoostaColor.glassStroke : .clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        }
    }
}

#Preview {
    TailoringPreviewView()
        .environmentObject(AppRouter())
        .environmentObject(AuthViewModel())
        .modelContainer(PreviewModelContainer.shared)
}
