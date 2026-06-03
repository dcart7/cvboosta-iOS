import SwiftUI
import UniformTypeIdentifiers

struct ATSScannerView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = ScannerViewModel()
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @State private var showPaywall = false

    private var canAnalyze: Bool {
        !viewModel.isScanning && viewModel.selectedFileName != nil && !viewModel.targetRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        resumeUploadCard
                        targetRoleCard
                        jobDescriptionCard
                        filtersCard
                        accessCard

                        PrimaryButton(
                            title: "Analyze Resume",
                            isLoading: viewModel.isScanning,
                            isDisabled: !canAnalyze
                        ) {
                            HapticsService.impact(.medium)
                            viewModel.analyzeResume()
                        }
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
            .sheet(isPresented: $showPaywall) {
                NavigationStack {
                    PaywallView()
                }
            }
        }
    }

    private var resumeUploadCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Resume upload", subtitle: "PDF only, up to 10 MB")

                SecondaryButton(title: "Upload Resume PDF") {
                    viewModel.startImport()
                }

                if let fileName = viewModel.selectedFileName {
                    Label(fileName, systemImage: "doc.richtext")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
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
                    .frame(minHeight: 130)
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
                        SecondaryButton(title: "Upgrade") {
                            showPaywall = true
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
}

#Preview {
    ATSScannerView()
        .environmentObject(AuthViewModel())
}
