import Foundation
import SwiftUI

@MainActor
final class ScannerViewModel: ObservableObject {
    enum ExperienceLevel: String, CaseIterable {
        case intern = "Intern"
        case junior = "Junior"
        case midLevel = "Mid-Level"
        case senior = "Senior"
        case lead = "Lead"
    }

    enum TargetMarket: String, CaseIterable {
        case unitedStates = "United States"
        case unitedKingdom = "United Kingdom"
        case europeanUnion = "European Union"
        case canada = "Canada"
        case global = "Global"
    }

    @Published var targetRole: String = ""
    @Published var jobDescription: String = ""
    @Published var experienceLevel: ExperienceLevel = .midLevel
    @Published var targetMarket: TargetMarket = .unitedStates

    @Published var selectedFileName: String?
    @Published private(set) var selectedFileURL: URL?
    @Published var isFileImporterPresented: Bool = false

    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0
    @Published var progressMessage: String = "Ready"
    @Published var progressStepIndex: Int = 0
    @Published var errorMessage: String?
    @Published var scanResult: ResumeScanResult?

    let loadingSteps: [String] = [
        "Reading resume structure",
        "Checking ATS compatibility",
        "Finding missing keywords",
        "Preparing improvement plan"
    ]

    private let aiService: AIService
    private let subscriptionService: SubscriptionService
    private var scanTask: Task<Void, Never>?

    init(
        aiService: AIService = GeminiClient(),
        subscriptionService: SubscriptionService = .shared
    ) {
        self.aiService = aiService
        self.subscriptionService = subscriptionService
    }

    func onAppear() {
        subscriptionService.refreshEntitlements()
    }

    func startImport() {
        errorMessage = nil
        isFileImporterPresented = true
    }

    func restorePurchases() async {
        await subscriptionService.restorePurchases()
    }

    func analyzeResume() {
        errorMessage = nil

        guard let fileURL = selectedFileURL else {
            errorMessage = "Please upload a PDF resume."
            return
        }

        let role = targetRole.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !role.isEmpty else {
            errorMessage = "Target role is required."
            return
        }

        scanTask?.cancel()
        scanTask = Task { [weak self] in
            guard let self else { return }
            await self.runScan(pdfURL: fileURL, role: role)
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanProgress = 0
        progressMessage = "Canceled"

        if #available(iOS 16.1, *) {
            Task {
                await LiveActivityManager.shared.fail()
            }
        }
    }

    func handlePickerResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let scoped = url.startAccessingSecurityScopedResource()
                defer {
                    if scoped {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
                if size > 10 * 1024 * 1024 {
                    errorMessage = "PDF file must be 10 MB or smaller."
                    return
                }
                selectedFileURL = url
                selectedFileName = url.lastPathComponent
                errorMessage = nil
            } catch {
                errorMessage = "Unable to read selected PDF."
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func runScan(pdfURL: URL, role: String) async {
        isScanning = true
        scanProgress = 0.08
        progressMessage = loadingSteps[0]
        progressStepIndex = 0

        await startLiveActivity()

        do {
            try Task.checkCancellation()

            let scoped = pdfURL.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    pdfURL.stopAccessingSecurityScopedResource()
                }
            }

            await updateProgress(value: 0.25, step: 1, eta: "~8s")

            try Task.checkCancellation()
            let response = try await aiService.scanResumePDF(
                fileURL: pdfURL,
                targetRole: role,
                jobDescription: normalizedJobDescription,
                experienceLevel: experienceLevel.rawValue,
                targetMarket: targetMarket.rawValue
            )

            try Task.checkCancellation()
            await updateProgress(value: 0.8, step: 2, eta: "~4s")
            await completeScan(with: response, isDemo: false, role: role)
        } catch is CancellationError {
            isScanning = false
            scanProgress = 0
            progressMessage = "Canceled"
        } catch {
            if AppEnvironment.demoFallbackEnabled && shouldUseDemoFallback(for: error) {
                await updateProgress(value: 0.9, step: 3, eta: "~1s")
                let response = DemoATSService.mockScanResult(for: role)
                await completeScan(with: response, isDemo: true, role: role)
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
    }

    private func completeScan(with response: ResumeScanResponse, isDemo: Bool, role: String) async {
        await updateProgress(value: 1.0, step: 3, eta: "")
        HapticsService.success()

        scanResult = ResumeScanResult(
            response: response,
            isDemo: isDemo,
            resumeName: selectedFileName ?? "Uploaded Resume",
            targetRole: role,
            experienceLevel: experienceLevel.rawValue,
            targetMarket: targetMarket.rawValue
        )

        isScanning = false
        progressMessage = "Ready"

        if #available(iOS 16.1, *) {
            await LiveActivityManager.shared.complete(finalScore: response.atsScore)
        }
    }

    private func updateProgress(value: Double, step: Int, eta: String) async {
        withAnimation(BoostaMotion.smooth) {
            scanProgress = value
            progressStepIndex = step
            progressMessage = loadingSteps[min(step, loadingSteps.count - 1)]
        }

        if #available(iOS 16.1, *) {
            await LiveActivityManager.shared.update(
                progress: value,
                detail: progressMessage,
                etaText: eta
            )
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

    private var normalizedJobDescription: String? {
        let value = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
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
