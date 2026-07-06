import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ATSScannerView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var trackedApplications: [ApplicationRecord]
    @StateObject private var viewModel = ScannerViewModel()
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @ObservedObject private var profileWorkspaceService = ProfileWorkspaceService.shared
    @State private var paywallContext: PaywallPresentationContext?
    @State private var currentStep: ScannerWizardStep = .upload
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

    private var canContinue: Bool {
        switch currentStep {
        case .upload:
            return viewModel.selectedFileName != nil
        case .role:
            return !viewModel.targetRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .job:
            return true
        case .review:
            return canAnalyze
        }
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
                        analysisPreviewCard
                        sessionCard
                        wizardProgressCard
                        currentStepCard
                        accessCard
                        wizardFooter
                    }
                    .padding(BoostaSpace.md)
                }

                if viewModel.isScanning {
                    LoadingOverlay(
                        title: "Analyzing your resume",
                        steps: viewModel.loadingSteps,
                        currentStep: viewModel.progressStepIndex,
                        progress: viewModel.scanProgress,
                        onCancel: {
                            viewModel.cancelScan()
                        }
                    )
                }
            }
            .navigationTitle("Scanner")
            .onAppear {
                viewModel.onAppear()
                Task {
                    await authViewModel.refreshSharedState()
                }
            }
            .onReceive(sessionTicker) { _ in
                _ = viewModel.sessionExpiredAndReset()
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
            .navigationDestination(isPresented: Binding(
                get: { viewModel.scanResult != nil },
                set: { newValue in
                    if !newValue {
                        viewModel.scanResult = nil
                    }
                }
            )) {
                if let result = viewModel.scanResult {
                    ATSResultsView(result: result)
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

    private var resumeUploadCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Step 1 • Upload CV", subtitle: "PDF only, up to 10 MB")

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

                SecondaryButton(title: "Upload Resume PDF") {
                    viewModel.startImport()
                }

                if let fileName = viewModel.selectedFileName {
                    HStack(spacing: 8) {
                        Label(fileName, systemImage: "doc.richtext")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                        if profileWorkspaceService.primaryResume?.displayName == fileName {
                            PrimaryResumeBadge()
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

    private var analysisPreviewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Stay recruiter-ready", subtitle: "Quick ATS diagnostics with clearer next steps")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                    KeywordChip(text: "ATS Parsing", status: .present)
                    KeywordChip(text: "Keyword Match", status: .weak)
                    KeywordChip(text: "Impact Score", status: .present)
                    KeywordChip(text: "Formatting Risk", status: .missing)
                    KeywordChip(text: "Role Alignment", status: .weak)
                    KeywordChip(text: "Readability", status: .present)
                }

                Text("You get critical issues, fast wins, and higher-impact changes instead of just one ATS number.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private var sessionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "Scanner session",
                    subtitle: "Your setup resets when the session expires."
                )

                HStack(spacing: BoostaSpace.sm) {
                    MetricPill(title: "Status", value: "Active", color: BoostaColor.accent)
                    MetricPill(title: "Expires", value: viewModel.scannerSessionLabel, color: BoostaColor.warning)
                }

                SecondaryButton(title: "Start New Session") {
                    viewModel.beginNewSession()
                }
            }
        }
    }

    private var targetRoleCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                TextInputField(
                    title: "Step 2 • Target role",
                    placeholder: "Backend Developer",
                    text: $viewModel.targetRole,
                    textContentType: .jobTitle
                )

                Text("This tells CVBoosta which hiring language and ATS signals matter most.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private var jobDescriptionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Step 3 • Job description", subtitle: "Optional, but it sharpens keyword targeting")
                TextEditor(text: $viewModel.jobDescription)
                    .frame(minHeight: 130)
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
                SectionHeader(title: "Step 4 • Review setup", subtitle: "Fine-tune the scan before you analyze")

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

    private var wizardProgressCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                HStack {
                    Text("Scanner flow")
                        .font(BoostaType.bodyStrong)
                    Spacer()
                    Text("Step \(currentStep.rawValue + 1) of \(ScannerWizardStep.allCases.count)")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }

                HStack(spacing: 8) {
                    ForEach(ScannerWizardStep.allCases) { step in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(step == currentStep ? BoostaColor.accent : step.rawValue < currentStep.rawValue ? BoostaColor.success : BoostaColor.surfaceMuted)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if step.rawValue < currentStep.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    } else {
                                        Text("\(step.rawValue + 1)")
                                            .font(BoostaType.caption)
                                            .foregroundStyle(step == currentStep ? .white : BoostaColor.secondaryText)
                                    }
                                }
                            Text(step.shortTitle)
                                .font(BoostaType.caption)
                                .foregroundStyle(step == currentStep ? BoostaColor.primaryText : BoostaColor.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var currentStepCard: some View {
        switch currentStep {
        case .upload:
            resumeUploadCard
        case .role:
            targetRoleCard
        case .job:
            jobDescriptionCard
        case .review:
            reviewCard
        }
    }

    private var reviewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Ready to analyze", subtitle: "One last look before we score recruiter visibility")

                filtersCard

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BoostaSpace.sm) {
                    ReviewMetricCard(title: "Resume", value: viewModel.selectedFileName ?? "Missing", tint: viewModel.selectedFileName == nil ? BoostaColor.warning : BoostaColor.success)
                    ReviewMetricCard(title: "Target role", value: viewModel.targetRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Missing" : viewModel.targetRole, tint: viewModel.targetRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? BoostaColor.warning : BoostaColor.accent)
                    ReviewMetricCard(title: "Experience", value: viewModel.experienceLevel.rawValue, tint: BoostaColor.accentSecondary)
                    ReviewMetricCard(title: "Market", value: viewModel.targetMarket.rawValue, tint: BoostaColor.warning)
                }

                Text(viewModel.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "No job description added. You can still analyze, but keyword targeting will be broader."
                    : "Job description added — keyword targeting and recruiter visibility will be sharper.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private var wizardFooter: some View {
        HStack(spacing: BoostaSpace.sm) {
            if currentStep != .upload {
                SecondaryButton(title: "Back") {
                    currentStep = currentStep.previous
                }
            }

            if currentStep == .review {
                PrimaryButton(
                    title: "Analyze Resume",
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
            } else {
                PrimaryButton(title: "Continue", isDisabled: !canContinue) {
                    currentStep = currentStep.next
                }
            }
        }
    }

    private var accessCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Usage")

                if subscriptionService.isPremium {
                    Text("Premium active: unlimited optimizations and deeper ATS intelligence")
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
                        PrimaryButton(title: "Unlock Premium") {
                            paywallContext = .optimizationLimit(resetDate: optimizationStatus.resetDate)
                        }
                        SecondaryButton(title: "Restore") {
                            Task {
                                await viewModel.restorePurchases()
                                await authViewModel.refreshSharedState()
                            }
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                }
            }
        }
    }

    private var limitReachedCard: some View {
        GlassCard(padding: BoostaSpace.sm) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Free limit reached for today", systemImage: "timer")
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.warning)
                Text("You can wait until \(optimizationStatus.resetDate.formatted(date: .omitted, time: .shortened)) for the next free run, or unlock unlimited optimizations now.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
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

#Preview {
    ATSScannerView()
        .environmentObject(AuthViewModel())
}

private enum ScannerWizardStep: Int, CaseIterable, Identifiable {
    case upload
    case role
    case job
    case review

    var id: Int { rawValue }

    var shortTitle: String {
        switch self {
        case .upload: return "Upload"
        case .role: return "Role"
        case .job: return "Job"
        case .review: return "Review"
        }
    }

    var next: ScannerWizardStep {
        ScannerWizardStep(rawValue: min(rawValue + 1, ScannerWizardStep.review.rawValue)) ?? .review
    }

    var previous: ScannerWizardStep {
        ScannerWizardStep(rawValue: max(rawValue - 1, ScannerWizardStep.upload.rawValue)) ?? .upload
    }
}

private struct ReviewMetricCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
            Text(value)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(tint)
                .lineLimit(2)
        }
        .padding(BoostaSpace.sm)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .background(BoostaColor.surfaceInteractive)
        .overlay(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(BoostaColor.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
    }
}
