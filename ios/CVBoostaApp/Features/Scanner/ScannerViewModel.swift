import Foundation

@MainActor
final class ScannerViewModel: ObservableObject {
    @Published var selectedRole: String = "Backend Developer"
    @Published var selectedFileName: String?
    @Published var isFileImporterPresented: Bool = false
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0
    @Published var progressMessage: String = "Ready"
    @Published var errorMessage: String?
    @Published var scanResult: ResumeScanResult?
    @Published var scanLimitStatus: ScanLimitStatus?

    let roles: [String] = [
        "Backend Developer",
        "Data Analyst",
        "Product Manager",
        "DevOps Engineer",
        "Marketing Manager"
    ]

    private let aiService: AIService
    private let scanLimitService: ScanLimitService
    private let subscriptionService: SubscriptionService

    init(
        aiService: AIService = GeminiClient(),
        scanLimitService: ScanLimitService = .shared,
        subscriptionService: SubscriptionService = .shared
    ) {
        self.aiService = aiService
        self.scanLimitService = scanLimitService
        self.subscriptionService = subscriptionService
    }

    func onAppear() {
        subscriptionService.refreshEntitlements()
        scanLimitStatus = scanLimitService.status(isPremium: subscriptionService.isPremium)
    }

    func startImport() {
        errorMessage = nil
        let status = scanLimitService.status(isPremium: subscriptionService.isPremium)
        scanLimitStatus = status
        guard status.canScan else {
            errorMessage = "Free plan limit reached. You get 1 scan per day."
            return
        }
        isFileImporterPresented = true
    }

    func restorePurchases() async {
        await subscriptionService.restorePurchases()
        scanLimitStatus = scanLimitService.status(isPremium: subscriptionService.isPremium)
    }

    func handlePickerResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            selectedFileName = url.lastPathComponent
            Task {
                await runScan(pdfURL: url)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    func runScan(pdfURL: URL) async {
        let status = scanLimitService.status(isPremium: subscriptionService.isPremium)
        scanLimitStatus = status

        guard status.canScan else {
            errorMessage = "Free plan limit reached. You get 1 scan per day."
            return
        }

        isScanning = true
        scanProgress = 0.03
        progressMessage = "Preparing file"
        errorMessage = nil

        await startLiveActivity()
        await updateProgress(value: 0.18, message: "Reading PDF", eta: "~8s")

        do {
            let scoped = pdfURL.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    pdfURL.stopAccessingSecurityScopedResource()
                }
            }

            await updateProgress(value: 0.44, message: "Uploading resume", eta: "~6s")
            let response = try await aiService.scanResumePDF(fileURL: pdfURL, targetRole: selectedRole)
            await updateProgress(value: 0.82, message: "Analyzing ATS signals", eta: "~2s")

            scanLimitService.recordScan(isPremium: subscriptionService.isPremium)
            await completeScan(with: response, isDemo: false)
        } catch {
            if AppEnvironment.demoFallbackEnabled && shouldUseDemoFallback(for: error) {
                await updateProgress(value: 0.66, message: "Backend unavailable, switching to demo", eta: "~2s")
                let response = DemoATSService.mockScanResult(for: selectedRole)
                scanLimitService.recordScan(isPremium: subscriptionService.isPremium)
                await completeScan(with: response, isDemo: true)
            } else {
                isScanning = false
                scanProgress = 0
                progressMessage = "Failed"
                errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
                if #available(iOS 16.1, *) {
                    await LiveActivityManager.shared.fail()
                }
            }
        }

        scanLimitStatus = scanLimitService.status(isPremium: subscriptionService.isPremium)
    }

    private func completeScan(with response: ResumeScanResponse, isDemo: Bool) async {
        await updateProgress(value: 1.0, message: "Done", eta: "")
        HapticsService.success()

        scanResult = ResumeScanResult(response: response, isDemo: isDemo)
        isScanning = false
        progressMessage = "Ready"

        if #available(iOS 16.1, *) {
            await LiveActivityManager.shared.complete(finalScore: response.atsScore)
        }
    }

    private func updateProgress(value: Double, message: String, eta: String) async {
        withAnimation(BoostaMotion.smooth) {
            scanProgress = value
            progressMessage = message
        }

        if #available(iOS 16.1, *) {
            await LiveActivityManager.shared.update(progress: value, detail: message, etaText: eta)
        }
    }

    private func startLiveActivity() async {
        if #available(iOS 16.1, *) {
            await LiveActivityManager.shared.startATSOptimization(
                title: "ATS Scan",
                detail: selectedFileName ?? "Resume"
            )
        }
    }

    private func shouldUseDemoFallback(for error: Error) -> Bool {
        guard let apiError = error as? APIError else {
            return false
        }

        switch apiError {
        case .transport, .invalidResponse, .invalidURL:
            return true
        case .server(let code, _):
            return code >= 500
        case .decoding:
            return false
        }
    }

}
