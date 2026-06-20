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
    @Published private(set) var primaryResumeSuggestion: ResumeUploadObservation?
    @Published var primaryResumeBubbleMessage: String?

    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0
    @Published var progressMessage: String = "Ready"
    @Published var progressStepIndex: Int = 0
    @Published var errorMessage: String?
    @Published var scanResult: ResumeScanResult?

    let loadingSteps: [String] = [
        "Matching keywords",
        "Optimizing readability",
        "Analyzing job requirements"
    ]

    private let atsService: ATSServiceProtocol
    private let subscriptionService: SubscriptionService
    private let widgetSyncService: WidgetSyncService
    private let sessionService: WorkspaceSessionService
    private let scanLimitService: ScanLimitService
    private let profileWorkspaceService: ProfileWorkspaceService
    private var scanTask: Task<Void, Never>?

    init(
        atsService: ATSServiceProtocol? = nil,
        subscriptionService: SubscriptionService? = nil,
        widgetSyncService: WidgetSyncService? = nil,
        sessionService: WorkspaceSessionService? = nil,
        scanLimitService: ScanLimitService = .shared,
        profileWorkspaceService: ProfileWorkspaceService? = nil
    ) {
        self.atsService = atsService ?? ATSService.shared
        self.subscriptionService = subscriptionService ?? .shared
        self.widgetSyncService = widgetSyncService ?? .shared
        self.sessionService = sessionService ?? .shared
        self.scanLimitService = scanLimitService
        self.profileWorkspaceService = profileWorkspaceService ?? .shared
    }

    func onAppear() {
        subscriptionService.refreshEntitlements()
        if !sessionExpiredAndReset() {
            sessionService.ensureSession(for: .scanner)
        }
        handlePendingScannerLaunchAction()
    }

    func startImport() {
        errorMessage = nil
        sessionService.touch(.scanner)
        isFileImporterPresented = true
    }

    func restorePurchases() async {
        await subscriptionService.restorePurchases()
    }

    func analyzeResume() {
        errorMessage = nil
        sessionService.touch(.scanner)

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

    @discardableResult
    func handlePickerResult(_ result: Result<URL, Error>) -> Bool {
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
                    return false
                }
                selectedFileURL = url
                selectedFileName = url.lastPathComponent
                errorMessage = nil
                primaryResumeSuggestion = try? profileWorkspaceService.observeResumeUpload(from: url)
                if primaryResumeSuggestion?.shouldSuggestPrimary == false {
                    primaryResumeSuggestion = nil
                }
                sessionService.touch(.scanner)
                return true
            } catch {
                errorMessage = "Unable to read selected PDF."
                return false
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    func beginNewSession() {
        sessionService.startNewSession(for: .scanner)
        resetSessionState()
    }

    @discardableResult
    func sessionExpiredAndReset() -> Bool {
        guard sessionService.resetIfExpired(.scanner) else {
            return false
        }

        resetSessionState()
        return true
    }

    var scannerSessionLabel: String {
        sessionService.formattedRemainingTime(for: .scanner)
    }

    func optimizationLimitStatus(backendRemaining: Int?) -> ScanLimitStatus {
        if subscriptionService.isPremium {
            return scanLimitService.status(isPremium: true)
        }

        let purchasedCredits = subscriptionService.scanCreditBalance

        if let backendRemaining {
            let totalRemaining = max(backendRemaining, 0) + purchasedCredits
            return ScanLimitStatus(
                canScan: totalRemaining > 0,
                scansRemaining: totalRemaining,
                resetDate: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
            )
        }

        let freeStatus = scanLimitService.status(isPremium: false)
        let totalRemaining = freeStatus.scansRemaining + purchasedCredits

        return ScanLimitStatus(
            canScan: totalRemaining > 0,
            scansRemaining: totalRemaining,
            resetDate: freeStatus.resetDate
        )
    }

    func usePrimaryResumeIfAvailable() {
        do {
            let selection = try profileWorkspaceService.primaryResumeSelection()
            selectedFileURL = selection.fileURL
            selectedFileName = selection.summary.displayName
            errorMessage = nil
            primaryResumeSuggestion = nil
            sessionService.touch(.scanner)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveSelectedResumeAsPrimary() {
        guard let selectedFileURL else {
            errorMessage = "Please upload a PDF resume."
            return
        }

        do {
            let storedResume = try profileWorkspaceService.importResume(
                from: selectedFileURL,
                suggestedName: selectedFileName,
                makePrimary: true
            )
            selectedFileName = storedResume.displayName
            primaryResumeSuggestion = nil
            primaryResumeBubbleMessage = "\(storedResume.displayName) is now your primary resume."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissPrimaryResumeSuggestion() {
        primaryResumeSuggestion = nil
    }

    func clearPrimaryResumeBubble() {
        primaryResumeBubbleMessage = nil
    }

    private func runScan(pdfURL: URL, role: String) async {
        isScanning = true
        scanProgress = 0.25
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

            await updateProgress(value: 0.56, step: 1, eta: "Live progress")

            try Task.checkCancellation()
            let response = try await atsService.scanResumePDF(
                fileURL: pdfURL,
                targetRole: role,
                jobDescription: normalizedJobDescription,
                experienceLevel: experienceLevel.rawValue,
                targetMarket: targetMarket.rawValue
            )

            try Task.checkCancellation()
            await updateProgress(value: 0.82, step: 2, eta: "Final refinement")
            await completeScan(with: response, isDemo: false, role: role)
        } catch is CancellationError {
            isScanning = false
            scanProgress = 0
            progressMessage = "Canceled"
        } catch {
            isScanning = false
            scanProgress = 0
            progressMessage = "Failed"
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            if #available(iOS 16.1, *) {
                await LiveActivityManager.shared.fail()
            }
        }
    }

    private func completeScan(with response: ResumeScanResponse, isDemo: Bool, role: String) async {
        await updateProgress(value: 1.0, step: 3, eta: "")
        HapticsService.success()
        sessionService.touch(.scanner)
        sessionService.touch(.tailoring)

        scanResult = ResumeScanResult(
            response: response,
            isDemo: isDemo,
            resumeName: selectedFileName ?? "Uploaded Resume",
            targetRole: role,
            experienceLevel: experienceLevel.rawValue,
            targetMarket: targetMarket.rawValue
        )
        if let scanResult {
            widgetSyncService.mergeLatestScan(result: scanResult)
        }
        if profileWorkspaceService.consumeFirstScanPrimaryBubbleEligibility() {
            primaryResumeBubbleMessage = "Tip: save a primary resume once and CVBoosta will auto-fill it next time."
        }

        let fallbackFreeRemaining = scanLimitService.status(isPremium: false).scansRemaining
        if subscriptionService.shouldUseConsumableScanCredit(fallbackFreeRemaining: fallbackFreeRemaining) {
            subscriptionService.consumeConsumableScanCredit()
        } else {
            scanLimitService.recordScan(isPremium: subscriptionService.isPremium)
            subscriptionService.consumeFreeOptimizationIfNeeded()
        }

        isScanning = false
        progressMessage = "Ready"

        if #available(iOS 16.1, *) {
            await LiveActivityManager.shared.complete(result: response)
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
                title: "ATS Analysis running",
                detail: loadingSteps[0]
            )
        }
    }

    private var normalizedJobDescription: String? {
        let value = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func resetSessionState() {
        targetRole = ""
        jobDescription = ""
        experienceLevel = .midLevel
        targetMarket = .unitedStates
        selectedFileName = nil
        selectedFileURL = nil
        primaryResumeSuggestion = nil
        primaryResumeBubbleMessage = nil
        scanResult = nil
        errorMessage = nil
        isScanning = false
        scanProgress = 0
        progressMessage = "Ready"
        progressStepIndex = 0
        scanTask?.cancel()
        scanTask = nil
    }

    private func handlePendingScannerLaunchAction() {
        switch profileWorkspaceService.consumeScannerLaunchAction() {
        case .usePrimaryResume:
            usePrimaryResumeIfAvailable()
        case .uploadAnother:
            startImport()
        case .none:
            break
        }
    }
}
