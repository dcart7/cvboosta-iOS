import SwiftUI
import SwiftData
import UIKit

/// iPad-only Tailoring workspace.
/// The iPhone Tailoring experience remains in `TailoringPreviewView` untouched.
struct TailoringWorkspaceView_iPad: View {
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

                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: BoostaSpace.lg) {
                            headerCard

                            if let payload = latestPayload {
                                workspaceBody(payload: payload, width: proxy.size.width)
                            } else {
                                emptyStateCard
                            }
                        }
                        .padding(.horizontal, BoostaSpace.xl)
                        .padding(.top, BoostaSpace.lg)
                        .padding(.bottom, BoostaSpace.xxl)
                        .frame(maxWidth: 1500)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.visible)
                }
            }
            .navigationTitle("Tailoring")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        appRouter.open(.scanner)
                    } label: {
                        Label("Re-scan", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .hoverEffect(.lift)

                    Button {
                        openURL(fallbackStudioURL())
                    } label: {
                        Label("Studio", systemImage: "safari")
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .hoverEffect(.lift)
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
        .overlay(alignment: .top) {
            if let errorMessage {
                ErrorBanner(message: errorMessage)
                    .padding(.horizontal, BoostaSpace.md)
                    .padding(.top, BoostaSpace.sm)
            }
        }
    }

    private var headerCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            HStack(alignment: .top, spacing: BoostaSpace.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tailoring Workspace")
                        .font(BoostaType.title)
                        .foregroundStyle(BoostaColor.primaryText)

                    if let payload = latestPayload {
                        Text("\(payload.resumeName) • \(payload.targetRole)")
                            .font(BoostaType.bodyStrong)
                            .foregroundStyle(BoostaColor.primaryText)
                        Text(payload.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    } else {
                        Text("Run a scan to unlock side-by-side improvements.")
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: BoostaSpace.sm) {
                    WorkspaceActionButton(title: "Re-scan", systemImage: "arrow.clockwise") {
                        appRouter.open(.scanner)
                    }

                    WorkspaceActionButton(title: "Open Studio", systemImage: "safari") {
                        openURL(fallbackStudioURL())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func workspaceBody(payload: LatestScanPayload, width: CGFloat) -> some View {
        let layout = TailoringWorkspaceLayout(width: width)

        if layout.isWide {
            HStack(alignment: .top, spacing: BoostaSpace.lg) {
                VStack(alignment: .leading, spacing: BoostaSpace.lg) {
                    originalCard(payload)
                    diffHighlightsCard(payload)
                    jobContextCard(payload)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                optimizedCard(payload)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                insightsSidebar(payload: payload)
                    .frame(width: 360)
            }
        } else {
            VStack(alignment: .leading, spacing: BoostaSpace.lg) {
                originalCard(payload)
                optimizedCard(payload)
                insightsSidebar(payload: payload)
            }
        }
    }

    private func originalCard(_ payload: LatestScanPayload) -> some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Original (parsed)", subtitle: "Extracted from your uploaded PDF")
                Text(payload.response.originalCVText)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(BoostaColor.secondaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func optimizedCard(_ payload: LatestScanPayload) -> some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Optimized", subtitle: "ATS-friendly version from CVBoosta backend")

                Text(payload.response.optimizedCV)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(BoostaColor.primaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: BoostaSpace.sm) {
                    WorkspaceActionButton(title: "Copy", systemImage: "doc.on.doc") {
                        copyToClipboard(payload.response.optimizedCV)
                    }
                    WorkspaceActionButton(title: "Save", systemImage: "bookmark") {
                        saveSuggestion(text: payload.response.optimizedCV, payload: payload)
                    }
                }
            }
        }
    }

    private func diffHighlightsCard(_ payload: LatestScanPayload) -> some View {
        let before = previewBullets(from: payload.response.originalCVText)
        let after = previewBullets(from: payload.response.optimizedCV)

        return GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Before → after", subtitle: "Quick proof of what changed")

                ForEach(Array(zip(before.indices, before)).prefix(2), id: \.0) { pair in
                    let index = pair.0
                    let oldLine = pair.1
                    VStack(alignment: .leading, spacing: 8) {
                        TailoringWorkspaceDiffLine(title: "Before", text: oldLine, tint: BoostaColor.secondaryText)
                        if after.indices.contains(index) {
                            TailoringWorkspaceDiffLine(title: "After", text: after[index], tint: BoostaColor.success)
                        }
                    }
                }
            }
        }
    }

    private func jobContextCard(_ payload: LatestScanPayload) -> some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Job context", subtitle: "What the optimization used as job text")
                Text(payload.response.jobText)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(10)
            }
        }
    }

    private func insightsSidebar(payload: LatestScanPayload) -> some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "ATS insights")

                HStack(spacing: BoostaSpace.md) {
                    ScoreRing(score: payload.response.atsScore)
                        .frame(width: 88, height: 88)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Baseline match")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                        Text("\(payload.response.atsScore)/100")
                            .font(BoostaType.section)

                        if let after = payload.response.matchAfter, after != payload.response.atsScore {
                            Text("After: \(after)/100")
                                .font(BoostaType.caption)
                                .foregroundStyle(after > payload.response.atsScore ? BoostaColor.success : BoostaColor.secondaryText)
                        }
                    }
                }

                Divider()
                    .opacity(0.35)

                VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                    SectionHeader(title: "Missing skills")
                    let missingLimit = subscriptionService.isPremium ? 18 : 10
                    if payload.response.missingSkills.isEmpty {
                        Text("No missing skills detected.")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(Array(payload.response.missingSkills.prefix(missingLimit)), id: \.self) { keyword in
                                KeywordChip(text: keyword, status: .missing)
                            }
                        }
                    }
                }

                if !payload.response.recommendations.isEmpty {
                    Divider()
                        .opacity(0.35)

                    VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                        SectionHeader(title: "Quick actions")
                        let recLimit = subscriptionService.isPremium ? 5 : 3
                        ForEach(Array(payload.response.recommendations.prefix(recLimit).enumerated()), id: \.offset) { idx, item in
                            HStack(alignment: .top, spacing: BoostaSpace.xs) {
                                Text("\(idx + 1).")
                                    .font(BoostaType.bodyStrong)
                                    .foregroundStyle(BoostaColor.accent)
                                Text(item)
                                    .font(BoostaType.caption)
                                    .foregroundStyle(BoostaColor.secondaryText)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyStateCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "No optimization yet",
                    subtitle: "Scan a resume to generate an ATS-optimized version and compare side-by-side."
                )
                WorkspaceActionButton(title: "Go to Scanner", systemImage: "doc.text.magnifyingglass") {
                    appRouter.open(.scanner)
                }
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
            URLQueryItem(name: "intent", value: "tailoring_workspace"),
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

        return Array(
            text
                .components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count > 24 }
                .prefix(3)
        )
    }
}

private struct TailoringWorkspaceDiffLine: View {
    let title: String
    let text: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(tint)

            Text(text)
                .font(BoostaType.caption)
                .foregroundStyle(title == "After" ? BoostaColor.primaryText : BoostaColor.secondaryText)
                .padding(.horizontal, BoostaSpace.sm)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(title == "After" ? BoostaColor.surfaceElevated : BoostaColor.surfaceMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                        .stroke(title == "After" ? BoostaColor.glassStroke : .clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        }
    }
}

private struct TailoringWorkspaceLayout {
    let isWide: Bool

    init(width: CGFloat) {
        isWide = width >= 980
    }
}

private struct WorkspaceActionButton: View {
    let title: String
    let systemImage: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
                .padding(.horizontal, BoostaSpace.md)
                .padding(.vertical, 10)
                .background(isDisabled ? Color.white.opacity(0.35) : Color.white.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                        .stroke(BoostaColor.glassStroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.65 : 1)
        .hoverEffect(.lift)
        .accessibilityLabel(title)
    }
}

#if DEBUG
#Preview("Tailoring Workspace (iPad)") {
    TailoringWorkspaceView_iPad()
        .environmentObject(AppRouter())
        .environmentObject(AuthViewModel())
        .modelContainer(PreviewModelContainer.shared)
}
#endif
