import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

/// iPad-only Scanner workspace.
/// The iPhone Scanner experience remains in `ATSScannerView` untouched.
struct ATSScannerWorkspaceView_iPad: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var trackedApplications: [ApplicationRecord]

    @StateObject private var viewModel = ScannerViewModel()
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @ObservedObject private var profileWorkspaceService = ProfileWorkspaceService.shared
    @State private var paywallContext: PaywallPresentationContext?
    @State private var sessionTicker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var optimizationStatus: ScanLimitStatus {
        viewModel.optimizationLimitStatus(backendRemaining: authViewModel.me?.usageLimits.scansRemainingToday)
    }

    private var canAnalyze: Bool {
        !viewModel.isScanning
            && viewModel.selectedFileName != nil
            && !viewModel.targetRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && optimizationStatus.canScan
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
                    let horizontalPadding = WorkspaceLayoutMetrics.horizontalPadding(for: proxy.size.width)

                    if layout.isWide {
                        HStack(alignment: .top, spacing: WorkspaceLayoutMetrics.gridSpacing) {
                            leftColumn
                                .frame(width: layout.leftColumnWidth)

                            rightColumn
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, BoostaSpace.md)
                        .padding(.bottom, BoostaSpace.xl)
                        .frame(maxWidth: 1580)
                        .frame(maxWidth: .infinity, alignment: .top)
                    } else {
                        ScrollView {
                            VStack(spacing: WorkspaceLayoutMetrics.gridSpacing) {
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
                        guard optimizationStatus.canScan else {
                            paywallContext = .optimizationLimit(resetDate: optimizationStatus.resetDate)
                            return
                        }
                        HapticsService.impact(.medium)
                        viewModel.analyzeResume()
                    } label: {
                        Label("Analyze", systemImage: "sparkles")
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!canAnalyze)
                    .opacity(canAnalyze ? 1 : 0.55)
                    .hoverEffect(.lift)

                    Button {
                        viewModel.beginNewSession()
                        LatestScanCacheStore.clear(in: modelContext)
                    } label: {
                        Label("New Session", systemImage: "arrow.counterclockwise")
                    }
                    .hoverEffect(.lift)
                }
            }
            .onAppear {
                viewModel.onAppear()
                Task { await authViewModel.refreshSharedState() }
            }
            .onReceive(sessionTicker) { _ in
                if viewModel.sessionExpiredAndReset() {
                    LatestScanCacheStore.clear(in: modelContext)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .background, viewModel.isScanning else { return }
                if #available(iOS 16.1, *) {
                    Task {
                        await LiveActivityManager.shared.markATSBackgrounded(
                            progress: viewModel.scanProgress,
                            detail: viewModel.progressMessage
                        )
                    }
                }
            }
            .onChange(of: viewModel.scanResult) { _, newValue in
                guard let result = newValue else { return }
                WidgetSyncService.shared.syncAfterLatestScan(
                    result: result,
                    user: authViewModel.me?.user,
                    scans: authViewModel.me?.scanHistory ?? [],
                    applications: trackedApplications
                )
                Task {
                    if #available(iOS 16.1, *) {
                        await LiveActivityManager.shared.celebrateDailyStreak(
                            dayCount: CVBoostaWidgetStore.loadSnapshot().streakDays,
                            detail: "ATS analysis completed. Momentum maintained."
                        )
                    }
                    await authViewModel.refreshSharedState()
                }
            }
            .fileImporter(
                isPresented: $viewModel.isFileImporterPresented,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        _ = viewModel.handlePickerResult(.success(url))
                    }
                case .failure(let error):
                    _ = viewModel.handlePickerResult(.failure(error))
                }
            }
            .sheet(item: $paywallContext) { context in
                NavigationStack {
                    PaywallView(context: context)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .overlay(alignment: .top) {
                if let message = viewModel.primaryResumeBubbleMessage {
                    ResumeFlowBubble(message: message)
                        .padding(.horizontal, BoostaSpace.md)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                                withAnimation(BoostaMotion.smooth) {
                                    viewModel.clearPrimaryResumeBubble()
                                }
                            }
                        }
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
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: BoostaSpace.sm) {
                        workflowHeaderCopy
                        Spacer(minLength: 0)
                        workflowHeaderStatus
                    }

                    VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                        workflowHeaderCopy
                        workflowHeaderStatus
                    }
                }

                WorkspaceActionButton(title: "Start New Session", systemImage: "arrow.counterclockwise") {
                    viewModel.beginNewSession()
                    LatestScanCacheStore.clear(in: modelContext)
                }
            }
        }
    }

    private var workflowHeaderCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ATS Scan Workspace")
                .font(BoostaType.title)
                .foregroundStyle(BoostaColor.primaryText)
            Text("Upload → analyze → iterate. Results stay side-by-side on iPad.")
                .font(BoostaType.body)
                .foregroundStyle(BoostaColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var workflowHeaderStatus: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BoostaSpace.sm) {
                workflowStatusPills
            }

            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                workflowStatusPills
            }
        }
    }

    private var workflowStatusPills: some View {
        Group {
            MetricPill(title: "Session", value: "Active", color: BoostaColor.accent)
            MetricPill(title: "Expires", value: viewModel.scannerSessionLabel, color: BoostaColor.warning)
        }
    }

    private var resumeUploadCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Resume upload", subtitle: "PDF only, up to 10 MB")

                if viewModel.selectedFileName == nil, let primaryResume = profileWorkspaceService.primaryResume {
                    ResumeAutofillPromptCard(
                        title: "Use Primary Resume?",
                        subtitle: "\(primaryResume.displayName) is ready to reuse instantly.",
                        primaryTitle: "Continue",
                        secondaryTitle: "Upload Another",
                        primaryAction: {
                            viewModel.usePrimaryResumeIfAvailable()
                        },
                        secondaryAction: {
                            viewModel.startImport()
                        }
                    )
                } else if viewModel.selectedFileName == nil, profileWorkspaceService.shouldShowPrimarySetupTip {
                    primaryResumeTipCard
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: BoostaSpace.sm) {
                        uploadResumeButton

                        if let fileName = viewModel.selectedFileName {
                            selectedResumeLabel(fileName)
                        }
                    }

                    VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                        uploadResumeButton

                        if let fileName = viewModel.selectedFileName {
                            selectedResumeLabel(fileName)
                        }
                    }
                }

                if let suggestion = viewModel.primaryResumeSuggestion {
                    ResumeRepeatedUploadSuggestionCard(
                        fileName: suggestion.displayName,
                        uploadCount: suggestion.uploadCount,
                        makePrimary: {
                            viewModel.saveSelectedResumeAsPrimary()
                        },
                        dismiss: {
                            viewModel.dismissPrimaryResumeSuggestion()
                        }
                    )
                }
            }
        }
    }

    private var uploadResumeButton: some View {
        WorkspaceActionButton(title: "Upload PDF", systemImage: "square.and.arrow.up") {
            viewModel.startImport()
        }
        .keyboardShortcut("o", modifiers: .command)
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
                    .background(BoostaColor.surfaceInteractiveStrong)
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
                    Text("Premium active: unlimited optimizations")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.success)
                } else {
                    let purchasedCredits = subscriptionService.scanCreditBalance
                    let usageText = if let remaining = authViewModel.me?.usageLimits.scansRemainingToday {
                        purchasedCredits > 0
                            ? "Optimizations available now: \(remaining + purchasedCredits) (\(remaining) free, \(purchasedCredits) purchased)"
                            : "Free plan optimizations remaining today: \(remaining)/1"
                    } else {
                        purchasedCredits > 0
                            ? "Free plan includes 1 optimization per day + \(purchasedCredits) purchased scan credit(s)"
                            : "Free plan includes 1 optimization per day"
                    }

                    Text(usageText)
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)

                    if !optimizationStatus.canScan {
                        limitReachedCard
                    }

                    HStack(spacing: BoostaSpace.sm) {
                        WorkspaceActionButton(title: "Upgrade", systemImage: "crown") {
                            paywallContext = .optimizationLimit(resetDate: optimizationStatus.resetDate)
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
                guard optimizationStatus.canScan else {
                    paywallContext = .optimizationLimit(resetDate: optimizationStatus.resetDate)
                    return
                }
                HapticsService.impact(.medium)
                viewModel.analyzeResume()
            }
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, BoostaSpace.md)
    }

    private var resultsEmptyState: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(
                    title: "Results panel",
                    subtitle: "Run an analysis to fill this workspace with recruiter visibility, ATS score, keyword gaps, and rewrite previews."
                )

                HStack(spacing: BoostaSpace.sm) {
                    WorkspaceActionButton(title: "Upload PDF", systemImage: "square.and.arrow.up") {
                        viewModel.startImport()
                    }
                    .keyboardShortcut("o", modifiers: .command)

                    WorkspaceActionButton(title: "Analyze", systemImage: "sparkles", isDisabled: !canAnalyze) {
                        guard optimizationStatus.canScan else {
                            paywallContext = .optimizationLimit(resetDate: optimizationStatus.resetDate)
                            return
                        }
                        HapticsService.impact(.medium)
                        viewModel.analyzeResume()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                }

                HStack(spacing: BoostaSpace.sm) {
                    ScannerPreviewCard(title: "Recruiter visibility", value: "Moderate", subtitle: "Animated after scan")
                    ScannerPreviewCard(title: "ATS trend", value: "7d / 30d", subtitle: "Shared account history")
                    ScannerPreviewCard(title: "Tailoring preview", value: "Before → After", subtitle: "Keyword and bullet diff")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("What shows up here")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)

                    ForEach([
                        "Score ring with recruiter-ready state",
                        "Missing keyword clusters by role",
                        "Before/after rewrite preview",
                        "Next-step recommendations and premium insights"
                    ], id: \.self) { line in
                        HStack(alignment: .top, spacing: BoostaSpace.xs) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(BoostaColor.accent)
                                .padding(.top, 2)
                            Text(line)
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 340, alignment: .top)
    }

    private var limitReachedCard: some View {
        GlassCard(padding: BoostaSpace.sm) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Free limit reached for today", systemImage: "timer")
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.warning)
                Text("Your next free optimization unlocks at \(optimizationStatus.resetDate.formatted(date: .omitted, time: .shortened)). Premium keeps this workspace unlimited.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private func selectedResumeLabel(_ fileName: String) -> some View {
        HStack(spacing: 8) {
            Label(fileName, systemImage: "doc.richtext")
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
                .lineLimit(1)

            if profileWorkspaceService.primaryResume?.displayName == fileName {
                PrimaryResumeBadge()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var primaryResumeTipCard: some View {
        GlassCard(padding: BoostaSpace.sm) {
            HStack(alignment: .top, spacing: BoostaSpace.xs) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(BoostaColor.warning)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Add one primary resume and CVBoosta will offer it automatically in Scanner, Tailoring, and quick resume flows.")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Hide tip") {
                        profileWorkspaceService.dismissPrimarySetupTip()
                    }
                    .buttonStyle(.plain)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.accent)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct ScannerWorkspaceLayout {
    let isWide: Bool
    let leftColumnWidth: CGFloat

    init(width: CGFloat) {
        isWide = width >= 920
        if width >= 1320 {
            leftColumnWidth = 500
        } else if width >= 1080 {
            leftColumnWidth = 480
        } else {
            leftColumnWidth = 440
        }
    }
}

private struct WorkspaceActionButton: View {
    let title: String
    let systemImage: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            HapticsService.tap()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
                .workspaceButtonLabelLayout()
                .padding(.horizontal, BoostaSpace.md)
                .padding(.vertical, 10)
                .background(isDisabled ? BoostaColor.surfaceDisabled : BoostaColor.surfaceInteractive)
                .overlay(
                    RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                        .stroke(BoostaColor.glassStroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        }
        .buttonStyle(BoostaDepthButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.65 : 1)
        .hoverEffect(.lift)
        .accessibilityLabel(title)
    }
}

private struct ScannerPreviewCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            Text(value)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text(subtitle)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.tertiaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, minHeight: WorkspaceLayoutMetrics.cardTileMinHeight, alignment: .leading)
        .padding(BoostaSpace.sm)
        .background(BoostaColor.surfaceInteractive)
        .overlay(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(BoostaColor.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
    }
}

private struct ATSResultsPanel_iPad: View {
    @EnvironmentObject private var appRouter: AppRouter
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    let result: ResumeScanResult

    @StateObject private var exportController = ResumeExportController()
    @State private var didPersistLatestScan = false

    var body: some View {
        GeometryReader { proxy in
            let columnCount = resultsColumnCount(for: proxy.size.width)
            let columns = Array(
                repeating: GridItem(.flexible(minimum: 320), spacing: WorkspaceLayoutMetrics.gridSpacing, alignment: .top),
                count: columnCount
            )

            LazyVGrid(columns: columns, alignment: .leading, spacing: WorkspaceLayoutMetrics.gridSpacing) {
                overviewCard
                    .gridCellColumns(columnCount)

                recommendationsCard
                    .gridCellColumns(min(2, columnCount))

                missingSkillsCard
                actionsCard

                optimizedCVCard
                    .gridCellColumns(columnCount)
            }
            .onAppear {
                persistLatestScanIfNeeded()
            }
            .animation(BoostaMotion.smooth, value: columnCount)
        }
        .frame(minHeight: 10)
        .confirmationDialog(
            "Download Resume",
            isPresented: $exportController.isExportOptionsPresented,
            titleVisibility: .visible
        ) {
            ForEach(ResumeExportFormat.allCases) { format in
                Button(format.title) {
                    exportController.export(
                        resumeName: result.resumeName,
                        optimizedText: result.response.optimizedCV,
                        format: format
                    )
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose the export format to share or save.")
        }
        .sheet(item: $exportController.shareItem, onDismiss: {
            exportController.cleanupSharedFile()
        }) { item in
            ShareSheet(items: [item.url])
        }
    }

    private func resultsColumnCount(for width: CGFloat) -> Int {
        WorkspaceLayoutMetrics.columnCount(
            for: width,
            minCardWidth: 320,
            maxColumns: 2,
            horizontalPadding: 0
        )
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
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: BoostaSpace.lg) {
                    resultsOverviewCopy
                    Spacer(minLength: 0)
                    resultsOverviewScore
                }

                VStack(alignment: .leading, spacing: BoostaSpace.md) {
                    resultsOverviewCopy
                    resultsOverviewScore
                }
            }
        }
    }

    private var resultsOverviewCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.resumeName)
                .font(BoostaType.title)
                .foregroundStyle(BoostaColor.primaryText)
            Text("\(result.targetRole) • \(result.experienceLevel) • \(result.targetMarket)")
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var resultsOverviewScore: some View {
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

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: BoostaSpace.sm) {
                        optimizedCVActions
                    }

                    VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                        optimizedCVActions
                    }
                }
            }
        }
    }

    private var optimizedCVActions: some View {
        Group {
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

    private var actionsCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "Download Resume",
                    subtitle: "Share this optimized version in the format you need."
                )

                PrimaryButton(
                    title: exportController.primaryActionTitle,
                    isLoading: exportController.isExporting
                ) {
                    exportController.presentOptions()
                }
                .hoverEffect(.lift)

                SecondaryButton(title: "Open Tailoring") {
                    appRouter.open(.tailoring)
                }
                .hoverEffect(.highlight)

                ResumeExportCapabilitiesView()

                if let successMessage = exportController.successMessage {
                    Text(successMessage)
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.success)
                }

                if let errorMessage = exportController.errorMessage {
                    Text(errorMessage)
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.danger)
                        .fixedSize(horizontal: false, vertical: true)

                    SecondaryButton(title: "Retry Export") {
                        exportController.retryLastExport()
                    }
                    .hoverEffect(.highlight)
                }
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
