import SwiftUI
import UniformTypeIdentifiers

struct ATSScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @State private var showPaywall = false

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
                        scannerCard
                        statusCard
                        limitCard
                    }
                    .padding(BoostaSpace.md)
                }
            }
            .navigationTitle("Scanner")
            .onAppear {
                viewModel.onAppear()
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

    private var scannerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                Text("ATS Resume Scanner")
                    .font(BoostaType.title)

                Text("Upload a PDF resume to run a real ATS compatibility scan.")
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)

                Picker("Target Role", selection: $viewModel.selectedRole) {
                    ForEach(viewModel.roles, id: \.self) { role in
                        Text(role).tag(role)
                    }
                }
                .pickerStyle(.menu)

                if let fileName = viewModel.selectedFileName {
                    Label(fileName, systemImage: "doc.richtext")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }

                Button(viewModel.isScanning ? "Scanning..." : "Select PDF and Scan") {
                    HapticsService.impact(.medium)
                    viewModel.startImport()
                }
                .buttonStyle(.borderedProminent)
                .tint(BoostaColor.accent)
                .disabled(viewModel.isScanning)
            }
        }
    }

    private var statusCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                Text("Scan Status")
                    .font(BoostaType.section)

                ProgressView(value: viewModel.scanProgress)
                    .tint(BoostaColor.accent)

                Text(viewModel.progressMessage)
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.danger)
                }
            }
        }
    }

    private var limitCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                Text("Plan Access")
                    .font(BoostaType.section)

                if subscriptionService.isPremium {
                    Text("Premium active: unlimited scans")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.success)
                } else {
                    Text("Free plan: 1 scan/day")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)

                    let remaining = viewModel.scanLimitStatus?.scansRemaining ?? 0
                    Text("Scans remaining today: \(remaining)")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)

                    HStack(spacing: BoostaSpace.sm) {
                        Button("Go Premium") {
                            showPaywall = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BoostaColor.accent)

                        Button("Restore") {
                            Task {
                                await viewModel.restorePurchases()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

#Preview {
    ATSScannerView()
}
