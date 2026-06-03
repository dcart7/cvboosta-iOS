import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

/// iPad-only Scanner workspace.
/// The iPhone Scanner experience remains in `ATSScannerView` untouched.
struct ATSScannerWorkspaceView_iPad: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel = ScannerViewModel()
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @State private var showPaywall = false

    private var canAnalyze: Bool {
        !viewModel.isScanning
            && viewModel.selectedFileName != nil
            && !viewModel.targetRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                    let layout = ScannerWorkspaceLayout(width: proxy.size.width)

                    if layout.isWide {
                        HStack(alignment: .top, spacing: BoostaSpace.lg) {
                            leftColumn
                                .frame(width: layout.leftColumnWidth)

                            rightColumn
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .padding(.horizontal, BoostaSpace.xl)
                        .padding(.top, BoostaSpace.lg)
                        .padding(.bottom, BoostaSpace.xl)
                        .frame(maxWidth: 1500)
                        .frame(maxWidth: .infinity, alignment: .top)
                    } else {
                        ScrollView {
                            VStack(spacing: BoostaSpace.lg) {
                                leftColumnContent
                                rightColumnContent
                            }
                            .padding(.horizontal, BoostaSpace.md)
                            .padding(.top, BoostaSpace.lg)
                            .padding(.bottom, BoostaSpace.xxl)
                            .frame(maxWidth: 900)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                if viewModel.isScanning {
                    LoadingOverlay(
                        title: "Analyzing your resume",
                        steps: viewModel.loadingSteps,
                        currentStep: viewModel.progressStepIndex,
                        progress: viewModel.scanProgress,
                        onCancel: { viewModel.cancelScan() }
                    )
                }
            }
            .navigationTitle("Scanner")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        viewModel.startImport()
                    } label: {
                        Label("Upload", systemImage: "square.and.arrow.up")
                    }
                    .keyboardShortcut("o", modifiers: .command)
                    .hoverEffect(.lift)

                    Button {
                        HapticsService.impact(.medium)
                        viewModel.analyzeResume()
                    } label: {
                        Label("Analyze", systemImage: "sparkles")
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!canAnalyze)
                    .opacity(canAnalyze ? 1 : 0.55)
                    .hoverEffect(.lift)
                }
            }
            .onAppear {
                viewModel.onAppear()
                Task { await authViewModel.refreshSharedState() }
            }
            .fileImporter(
                isPresented: $viewModel.isFileImporterPresented,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.handlePickerResult(.success(url))
                    }
                case .failure(let error):
                    viewModel.handlePickerResult(.failure(error))
                }
            }
            .sheet(isPresented: $showPaywall) {
                NavigationStack {
                    PaywallView()
                }
            }
        }
    }

    private var leftColumn: some View {
        ScrollView {
            leftColumnContent
                .padding(.bottom, BoostaSpace.xxl)
        }
        .scrollIndicators(.visible)
        .safeAreaInset(edge: .bottom) {
            analyzeBar
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
        }
    }

    private var leftColumnContent: some View {
        VStack(spacing: BoostaSpace.md) {
            workflowHeader
            resumeUploadCard
            targetRoleCard
            jobDescriptionCard
            filtersCard
            accessCard

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }
        }
    }

    private var rightColumn: some View {
        ScrollView {
            rightColumnContent
                .padding(.bottom, BoostaSpace.xxl)
        }
        .scrollIndicators(.visible)
    }

    @ViewBuilder
    private var rightColumnContent: some View {
        VStack(spacing: BoostaSpace.lg) {
            if let result = viewModel.scanResult {
                ATSResultsPanel_iPad(result: result)
                    .environmentObject(authViewModel)
                    .environment(\.modelContext, modelContext)
            } else {
                resultsEmptyState
            }
        }
    }

    private var workflowHeader: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ATS Scan Workspace")
                    .font(BoostaType.title)
                    .foregroundStyle(BoostaColor.primaryText)
                Text("Upload → analyze → iterate. Results stay side-by-side on iPad.")
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private var resumeUploadCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Resume upload", subtitle: "PDF only, up to 10 MB")

                HStack(spacing: BoostaSpace.sm) {
                    WorkspaceActionButton(title: "Upload PDF", systemImage: "square.and.arrow.up") {
                        viewModel.startImport()
                    }
                    .keyboardShortcut("o", modifiers: .command)

                    if let fileName = viewModel.selectedFileName {
                        Label(fileName, systemImage: "doc.richtext")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var targetRoleCard: some View {
        GlassCard {
            TextInputField(
                title: "Target role",
                placeholder: "Backend Developer",
                text: $viewModel.targetRole,
                textContentType: .jobTitle
            )
        }
    }

    private var jobDescriptionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Job description", subtitle: "Optional, recommended 100+ characters")
                TextEditor(text: $viewModel.jobDescription)
                    .frame(minHeight: 150)
                    .padding(BoostaSpace.xs)
                    .background(Color.white.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                            .stroke(BoostaColor.glassStroke, lineWidth: 1)
                    )
                Text("\(viewModel.jobDescription.count) characters")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var filtersCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Experience & market")

                Picker("Experience level", selection: $viewModel.experienceLevel) {
                    ForEach(ScannerViewModel.ExperienceLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.menu)

                Picker("Target country/market", selection: $viewModel.targetMarket) {
                    ForEach(ScannerViewModel.TargetMarket.allCases, id: \.self) { market in
                        Text(market.rawValue).tag(market)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var accessCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Usage")

                if subscriptionService.isPremium {
                    Text("Premium active: unlimited ATS scans")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.success)
                } else {
                    let usageText = if let remaining = authViewModel.me?.usageLimits.scansRemainingToday {
                        "Free plan remaining today: \(remaining)"
                    } else {
                        "Free plan remaining today: —"
                    }

                    Text(usageText)
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)

                    HStack(spacing: BoostaSpace.sm) {
                        WorkspaceActionButton(title: "Upgrade", systemImage: "crown") {
                            showPaywall = true
                        }
                        WorkspaceActionButton(title: "Restore", systemImage: "arrow.clockwise") {
                            Task {
                                await viewModel.restorePurchases()
                                await authViewModel.refreshSharedState()
                            }
                        }
                    }
                }
            }
        }
    }

    private var analyzeBar: some View {
        HStack(spacing: BoostaSpace.sm) {
            PrimaryButton(
                title: viewModel.isScanning ? "Analyzing..." : "Analyze Resume",
                isLoading: viewModel.isScanning,
                isDisabled: !canAnalyze
            ) {
                HapticsService.impact(.medium)
                viewModel.analyzeResume()
            }
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, BoostaSpace.md)
    }

    private var resultsEmptyState: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "Results panel",
                    subtitle: "Run an analysis to see ATS score, keyword gaps, and rewrite previews here."
                )

                HStack(spacing: BoostaSpace.sm) {
                    WorkspaceActionButton(title: "Upload PDF", systemImage: "square.and.arrow.up") {
                        viewModel.startImport()
                    }
                    .keyboardShortcut("o", modifiers: .command)

                    WorkspaceActionButton(title: "Analyze", systemImage: "sparkles", isDisabled: !canAnalyze) {
                        HapticsService.impact(.medium)
                        viewModel.analyzeResume()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
    }
}

private struct ScannerWorkspaceLayout {
    let isWide: Bool
    let leftColumnWidth: CGFloat

    init(width: CGFloat) {
        isWide = width >= 980
        if width >= 1200 {
            leftColumnWidth = 460
        } else {
            leftColumnWidth = 420
        }
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

private struct ATSResultsPanel_iPad: View {
    @EnvironmentObject private var appRouter: AppRouter
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    let result: ResumeScanResult

    @State private var didPersistLatestScan = false

    var body: some View {
        GeometryReader { proxy in
            let columnCount = resultsColumnCount(for: proxy.size.width)
            let columns = Array(
                repeating: GridItem(.flexible(minimum: 320), spacing: BoostaSpace.lg, alignment: .top),
                count: columnCount
            )

            LazyVGrid(columns: columns, alignment: .leading, spacing: BoostaSpace.lg) {
                overviewCard
                    .gridCellColumns(columnCount)

                recommendationsCard
                    .gridCellColumns(min(2, columnCount))

                missingSkillsCard
                actionsCard

                optimizedCVCard
                    .gridCellColumns(columnCount)

                feedbackCard
                    .gridCellColumns(columnCount)
            }
            .onAppear {
                persistLatestScanIfNeeded()
            }
            .animation(BoostaMotion.smooth, value: columnCount)
        }
        .frame(minHeight: 10)
    }

    private func resultsColumnCount(for width: CGFloat) -> Int {
        if width >= 1100 { return 2 }
        return 1
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
        GlassCard(padding: BoostaSpace.lg) {
            HStack(alignment: .top, spacing: BoostaSpace.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.resumeName)
                        .font(BoostaType.title)
                        .foregroundStyle(BoostaColor.primaryText)
                    Text("\(result.targetRole) • \(result.experienceLevel) • \(result.targetMarket)")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }

                Spacer(minLength: 0)

                HStack(spacing: BoostaSpace.md) {
                    ScoreRing(score: result.response.atsScore)
                        .frame(width: 116, height: 116)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Baseline match")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                        Text("\(result.response.atsScore)/100")
                            .font(BoostaType.section)
                        if let after = result.response.matchAfter, after != result.response.atsScore {
                            Text("After: \(after)/100")
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
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Recommendations", subtitle: "Backend-generated next steps")

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
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Missing skills / keywords")

                let limit = subscriptionService.isPremium ? 18 : 10
                if result.response.missingSkills.isEmpty {
                    Text("No missing skills detected.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(Array(result.response.missingSkills.prefix(limit)), id: \.self) { keyword in
                            KeywordChip(text: keyword, status: .missing)
                        }
                    }
                }
            }
        }
    }

    private var optimizedCVCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Optimized resume", subtitle: "Side-by-side is available in Tailoring")

                Text(result.response.optimizedCV)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
                    .textSelection(.enabled)
                    .lineLimit(22)

                HStack(spacing: BoostaSpace.sm) {
                    SecondaryButton(title: "Copy optimized") {
                        UIPasteboard.general.string = result.response.optimizedCV
                        HapticsService.success()
                    }
                    .hoverEffect(.highlight)

                    SecondaryButton(title: "Open Tailoring") {
                        appRouter.open(.tailoring)
                    }
                    .hoverEffect(.highlight)
                }
            }
        }
    }

    private var feedbackCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
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
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Next")

                PrimaryButton(title: "Open Tailoring") {
                    appRouter.open(.tailoring)
                }
                .hoverEffect(.lift)

                SecondaryButton(title: "Save Report") {
                    HapticsService.success()
                }
                .hoverEffect(.highlight)
            }
        }
    }
}

#if DEBUG
#Preview("Scanner Workspace (iPad)") {
    ATSScannerWorkspaceView_iPad()
        .environmentObject(AuthViewModel())
        .environmentObject(AppRouter())
        .modelContainer(PreviewModelContainer.shared)
}
#endif
