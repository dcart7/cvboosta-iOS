import CryptoKit
import Foundation

struct ProfileWorkspaceSettings: Codable, Equatable {
    var displayNameOverride: String
    var jobTarget: String
    var preferredCountry: String
    var language: String
    var avatarFileName: String?

    static let empty = ProfileWorkspaceSettings(
        displayNameOverride: "",
        jobTarget: "",
        preferredCountry: "United States",
        language: "English",
        avatarFileName: nil
    )
}

struct StoredResumeSummary: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var originalFileName: String
    var storageFileName: String
    var fileHash: String
    var createdAt: Date
    var lastUsedAt: Date
    var uploadCount: Int
    var isPrimary: Bool
}

struct ResumeUploadObservation: Equatable {
    let displayName: String
    let uploadCount: Int
    let shouldSuggestPrimary: Bool
}

struct ResumeExportActivity: Codable, Identifiable, Hashable {
    let id: UUID
    let resumeName: String
    let formatRawValue: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        resumeName: String,
        format: ResumeExportFormat,
        createdAt: Date = .now
    ) {
        self.id = id
        self.resumeName = resumeName
        self.formatRawValue = format.rawValue
        self.createdAt = createdAt
    }

    var format: ResumeExportFormat? {
        ResumeExportFormat(rawValue: formatRawValue)
    }
}

enum ScannerResumeLaunchAction: Equatable {
    case usePrimaryResume
    case uploadAnother
}

struct PrimaryResumeSelection {
    let summary: StoredResumeSummary
    let fileURL: URL
}

private struct ProfileResumeResource: Sendable {
    let data: Data
    let fileName: String
    let fileHash: String
}

private func loadProfileResumeResource(from url: URL) throws -> ProfileResumeResource {
    let scoped = url.startAccessingSecurityScopedResource()
    defer {
        if scoped {
            url.stopAccessingSecurityScopedResource()
        }
    }

    do {
        let values = try url.resourceValues(forKeys: [.nameKey, .fileSizeKey])
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        if let size = values.fileSize, size > 10 * 1024 * 1024 {
            throw ProfileWorkspaceService.WorkspaceError.fileTooLarge
        }
        if data.count > 10 * 1024 * 1024 {
            throw ProfileWorkspaceService.WorkspaceError.fileTooLarge
        }

        return ProfileResumeResource(
            data: data,
            fileName: values.name ?? url.lastPathComponent,
            fileHash: SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        )
    } catch let error as ProfileWorkspaceService.WorkspaceError {
        throw error
    } catch {
        throw ProfileWorkspaceService.WorkspaceError.unreadableFile
    }
}

@MainActor
final class ProfileWorkspaceService: ObservableObject {
    static let shared = ProfileWorkspaceService()

    @Published private(set) var settings: ProfileWorkspaceSettings
    @Published private(set) var avatarData: Data?
    @Published private(set) var savedResumes: [StoredResumeSummary]
    @Published private(set) var exportHistory: [ResumeExportActivity]

    private let defaults: UserDefaults
    private let fileManager: FileManager

    private var pendingScannerLaunchAction: ScannerResumeLaunchAction?
    private var uploadTracking: [String: UploadTrackingRecord]

    private enum DefaultsKey {
        static let settings = "cvboosta.profile_workspace.settings"
        static let resumes = "cvboosta.profile_workspace.resumes"
        static let resumesRevisionAt = "cvboosta.profile_workspace.resumes.revision_at"
        static let uploadTracking = "cvboosta.profile_workspace.upload_tracking"
        static let exportHistory = "cvboosta.profile_workspace.export_history"
        static let primaryTipDismissed = "cvboosta.profile_workspace.primary_tip_dismissed"
        static let firstScanBubbleShown = "cvboosta.profile_workspace.first_scan_bubble_shown"
    }

    private struct UploadTrackingRecord: Codable {
        var fileName: String
        var count: Int
        var lastUploadedAt: Date
    }

    enum WorkspaceError: LocalizedError {
        case unreadableFile
        case fileTooLarge
        case missingPrimaryResume

        var errorDescription: String? {
            switch self {
            case .unreadableFile:
                return "Could not read the selected resume."
            case .fileTooLarge:
                return "Resume PDF must be 10 MB or smaller."
            case .missingPrimaryResume:
                return "Your primary resume is no longer available. Please upload it again."
            }
        }
    }

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.settings = Self.loadValue(forKey: DefaultsKey.settings, from: defaults) ?? .empty
        self.savedResumes = Self.loadValue(forKey: DefaultsKey.resumes, from: defaults) ?? []
        self.uploadTracking = Self.loadValue(forKey: DefaultsKey.uploadTracking, from: defaults) ?? [:]
        self.exportHistory = Self.loadValue(forKey: DefaultsKey.exportHistory, from: defaults) ?? []
        self.avatarData = nil

        normalizeStoredState()
        ensureResumeRevisionExists()
        avatarData = loadAvatarData()
    }

    var primaryResume: StoredResumeSummary? {
        savedResumes.first(where: \.isPrimary)
    }

    var shouldShowPrimarySetupTip: Bool {
        primaryResume == nil && !defaults.bool(forKey: DefaultsKey.primaryTipDismissed)
    }

    var resumeSyncRevisionDate: Date {
        if let stored = defaults.object(forKey: DefaultsKey.resumesRevisionAt) as? Date {
            return stored
        }

        let derived = savedResumes
            .map { max($0.lastUsedAt, $0.createdAt) }
            .max() ?? .distantPast
        return derived
    }

    func dismissPrimarySetupTip() {
        defaults.set(true, forKey: DefaultsKey.primaryTipDismissed)
        objectWillChange.send()
    }

    func consumeFirstScanPrimaryBubbleEligibility() -> Bool {
        guard primaryResume == nil else { return false }
        guard !defaults.bool(forKey: DefaultsKey.firstScanBubbleShown) else { return false }
        defaults.set(true, forKey: DefaultsKey.firstScanBubbleShown)
        return true
    }

    func effectiveDisplayName(fallback: String?) -> String {
        let override = settings.displayNameOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty {
            return override
        }
        let fallbackValue = fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fallbackValue.isEmpty ? "Your Profile" : fallbackValue
    }

    func initials(fallback: String?) -> String {
        let source = effectiveDisplayName(fallback: fallback)
        let parts = source
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        let joined = parts.joined()
        return joined.isEmpty ? "CV" : joined
    }

    func updateDisplayName(_ value: String) {
        settings.displayNameOverride = value
        persistSettings()
    }

    func updateJobTarget(_ value: String) {
        settings.jobTarget = value
        persistSettings()
    }

    func updatePreferredCountry(_ value: String) {
        settings.preferredCountry = value
        persistSettings()
    }

    func updateLanguage(_ value: String) {
        settings.language = value
        persistSettings()
    }

    func saveAvatarData(_ data: Data?) async throws {
        if let data {
            let fileName = settings.avatarFileName ?? "profile-avatar.jpg"
            try ensureDirectoryExists(at: baseDirectoryURL)
            let destinationURL = avatarURL(fileName: fileName)
            try await Task.detached(priority: .userInitiated) {
                try data.write(to: destinationURL, options: .atomic)
            }.value
            settings.avatarFileName = fileName
            avatarData = data
        } else if let fileName = settings.avatarFileName {
            let destinationURL = avatarURL(fileName: fileName)
            try? await Task.detached(priority: .utility) {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
            }.value
            settings.avatarFileName = nil
            avatarData = nil
        } else {
            avatarData = nil
        }

        persistSettings()
    }

    func importResume(
        from url: URL,
        suggestedName: String? = nil,
        makePrimary: Bool = false
    ) async throws -> StoredResumeSummary {
        let resource = try await readResumeResource(from: url)
        let displayName = normalizedDisplayName(
            suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines),
            fallbackFileName: resource.fileName
        )
        let now = Date()

        if let existingIndex = savedResumes.firstIndex(where: { $0.fileHash == resource.fileHash }) {
            savedResumes[existingIndex].displayName = displayName
            savedResumes[existingIndex].originalFileName = resource.fileName
            savedResumes[existingIndex].lastUsedAt = now
            savedResumes[existingIndex].uploadCount += 1
            uploadTracking[resource.fileHash] = UploadTrackingRecord(
                fileName: resource.fileName,
                count: savedResumes[existingIndex].uploadCount,
                lastUploadedAt: now
            )

            if makePrimary || primaryResume == nil {
                markPrimaryResume(id: savedResumes[existingIndex].id)
            } else {
                persistResumes()
            }

            return savedResumes.first(where: { $0.id == savedResumes[existingIndex].id }) ?? savedResumes[existingIndex]
        }

        try ensureDirectoryExists(at: resumesDirectoryURL)
        let storageFileName = "\(UUID().uuidString).pdf"
        let destinationURL = resumeURL(fileName: storageFileName)
        try await Task.detached(priority: .userInitiated) {
            try resource.data.write(to: destinationURL, options: .atomic)
        }.value

        var summary = StoredResumeSummary(
            id: UUID(),
            displayName: displayName,
            originalFileName: resource.fileName,
            storageFileName: storageFileName,
            fileHash: resource.fileHash,
            createdAt: now,
            lastUsedAt: now,
            uploadCount: max(uploadTracking[resource.fileHash]?.count ?? 0, 1),
            isPrimary: false
        )

        uploadTracking[resource.fileHash] = UploadTrackingRecord(
            fileName: resource.fileName,
            count: summary.uploadCount,
            lastUploadedAt: now
        )

        savedResumes.append(summary)
        if makePrimary || primaryResume == nil {
            markPrimaryResume(id: summary.id)
            summary = savedResumes.first(where: { $0.id == summary.id }) ?? summary
        } else {
            persistResumes()
        }
        return summary
    }

    func observeResumeUpload(from url: URL) async throws -> ResumeUploadObservation {
        let resource = try await readResumeResource(from: url)
        let now = Date()

        if let existingIndex = savedResumes.firstIndex(where: { $0.fileHash == resource.fileHash }) {
            savedResumes[existingIndex].lastUsedAt = now
            savedResumes[existingIndex].uploadCount += 1
            uploadTracking[resource.fileHash] = UploadTrackingRecord(
                fileName: resource.fileName,
                count: savedResumes[existingIndex].uploadCount,
                lastUploadedAt: now
            )
            persistResumes()

            return ResumeUploadObservation(
                displayName: savedResumes[existingIndex].displayName,
                uploadCount: savedResumes[existingIndex].uploadCount,
                shouldSuggestPrimary: !savedResumes[existingIndex].isPrimary && savedResumes[existingIndex].uploadCount >= 5
            )
        }

        let nextCount = (uploadTracking[resource.fileHash]?.count ?? 0) + 1
        uploadTracking[resource.fileHash] = UploadTrackingRecord(
            fileName: resource.fileName,
            count: nextCount,
            lastUploadedAt: now
        )
        persistUploadTracking()

        return ResumeUploadObservation(
            displayName: normalizedDisplayName(nil, fallbackFileName: resource.fileName),
            uploadCount: nextCount,
            shouldSuggestPrimary: primaryResume?.fileHash != resource.fileHash && nextCount >= 5
        )
    }

    func primaryResumeSelection() throws -> PrimaryResumeSelection {
        guard let primaryResume else {
            throw WorkspaceError.missingPrimaryResume
        }
        let url = resumeURL(fileName: primaryResume.storageFileName)
        guard fileManager.fileExists(atPath: url.path) else {
            throw WorkspaceError.missingPrimaryResume
        }

        touchResumeUsage(id: primaryResume.id)
        return PrimaryResumeSelection(
            summary: savedResumes.first(where: { $0.id == primaryResume.id }) ?? primaryResume,
            fileURL: url
        )
    }

    func setPrimaryResume(_ resumeID: UUID) {
        markPrimaryResume(id: resumeID)
    }

    func deleteResume(_ resumeID: UUID) {
        guard let index = savedResumes.firstIndex(where: { $0.id == resumeID }) else { return }
        let removed = savedResumes.remove(at: index)
        try? fileManager.removeItem(at: resumeURL(fileName: removed.storageFileName))

        if removed.isPrimary, let fallback = savedResumes.first {
            markPrimaryResume(id: fallback.id)
        } else {
            persistResumes()
        }
    }

    func queueScannerLaunchAction(_ action: ScannerResumeLaunchAction) {
        pendingScannerLaunchAction = action
    }

    func consumeScannerLaunchAction() -> ScannerResumeLaunchAction? {
        defer { pendingScannerLaunchAction = nil }
        return pendingScannerLaunchAction
    }

    func recordExport(format: ResumeExportFormat, resumeName: String) {
        exportHistory.insert(
            ResumeExportActivity(
                resumeName: resumeName,
                format: format
            ),
            at: 0
        )
        exportHistory = Array(exportHistory.prefix(24))
        persistExportHistory()
    }

    func exportCount(for format: ResumeExportFormat) -> Int {
        exportHistory.filter { $0.format == format }.count
    }

    func mergedResumeNames(remoteNames: [String]) -> [String] {
        var result: [String] = []

        for name in remoteNames where !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !result.contains(name) {
                result.append(name)
            }
        }

        for resume in savedResumes {
            if !result.contains(resume.displayName) {
                result.append(resume.displayName)
            }
        }

        return result
    }

    func combinedResumeCount(remoteNames: [String]) -> Int {
        mergedResumeNames(remoteNames: remoteNames).count
    }

    func exportCloudResumePayloads() async -> [CloudResumePayload] {
        await withTaskGroup(of: CloudResumePayload?.self) { group in
            for resume in savedResumes {
                group.addTask { [fileManager] in
                    let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                        ?? fileManager.temporaryDirectory
                    let baseDirectory = root.appendingPathComponent("CVBoostaProfileWorkspace", isDirectory: true)
                    let fileURL = baseDirectory
                        .appendingPathComponent("Resumes", isDirectory: true)
                        .appendingPathComponent(resume.storageFileName)

                    guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
                        return nil
                    }

                    return CloudResumePayload(
                        fileHash: resume.fileHash,
                        resumeID: resume.id,
                        displayName: resume.displayName,
                        originalFileName: resume.originalFileName,
                        createdAt: resume.createdAt,
                        lastUsedAt: resume.lastUsedAt,
                        uploadCount: resume.uploadCount,
                        isPrimary: resume.isPrimary,
                        updatedAt: max(resume.lastUsedAt, resume.createdAt),
                        pdfData: data
                    )
                }
            }

            var payloads: [CloudResumePayload] = []
            for await payload in group {
                if let payload {
                    payloads.append(payload)
                }
            }
            return payloads.sorted { lhs, rhs in
                if lhs.isPrimary != rhs.isPrimary {
                    return lhs.isPrimary && !rhs.isPrimary
                }
                return lhs.lastUsedAt > rhs.lastUsedAt
            }
        }
    }

    func applyCloudResumePayloads(_ payloads: [CloudResumePayload], syncDate: Date) async {
        guard !payloads.isEmpty else { return }

        let incomingByHash = Dictionary(uniqueKeysWithValues: payloads.map { ($0.fileHash, $0) })
        let existingByHash = Dictionary(uniqueKeysWithValues: savedResumes.map { ($0.fileHash, $0) })
        let removedHashes = Set(existingByHash.keys).subtracting(incomingByHash.keys)

        for removedHash in removedHashes {
            if let removed = existingByHash[removedHash] {
                try? fileManager.removeItem(at: resumeURL(fileName: removed.storageFileName))
            }
        }

        var updatedResumes: [StoredResumeSummary] = []
        updatedResumes.reserveCapacity(payloads.count)

        for payload in payloads {
            let storageFileName = existingByHash[payload.fileHash]?.storageFileName ?? "\(UUID().uuidString).pdf"
            let destinationURL = resumeURL(fileName: storageFileName)

            do {
                try ensureDirectoryExists(at: resumesDirectoryURL)
                if !fileManager.fileExists(atPath: destinationURL.path) {
                    try payload.pdfData.write(to: destinationURL, options: .atomic)
                }
            } catch {
                continue
            }

            uploadTracking[payload.fileHash] = UploadTrackingRecord(
                fileName: payload.originalFileName,
                count: payload.uploadCount,
                lastUploadedAt: payload.lastUsedAt
            )

            updatedResumes.append(
                StoredResumeSummary(
                    id: payload.resumeID,
                    displayName: payload.displayName,
                    originalFileName: payload.originalFileName,
                    storageFileName: storageFileName,
                    fileHash: payload.fileHash,
                    createdAt: payload.createdAt,
                    lastUsedAt: payload.lastUsedAt,
                    uploadCount: payload.uploadCount,
                    isPrimary: payload.isPrimary
                )
            )
        }

        savedResumes = updatedResumes
        persistResumes(syncDate: syncDate)
    }

    private func normalizeStoredState() {
        savedResumes = savedResumes.filter { fileManager.fileExists(atPath: resumeURL(fileName: $0.storageFileName).path) }

        if savedResumes.count(where: { $0.isPrimary }) > 1 {
            if let firstPrimary = savedResumes.first(where: { $0.isPrimary }) {
                markPrimaryResume(id: firstPrimary.id)
            }
        } else if !savedResumes.isEmpty && primaryResume == nil {
            markPrimaryResume(id: savedResumes[0].id)
        } else {
            sortResumes()
            persistResumes()
        }
    }

    private func persistSettings() {
        Self.storeValue(settings, forKey: DefaultsKey.settings, in: defaults)
        objectWillChange.send()
    }

    private func persistResumes(syncDate: Date = .now) {
        sortResumes()
        Self.storeValue(savedResumes, forKey: DefaultsKey.resumes, in: defaults)
        defaults.set(syncDate, forKey: DefaultsKey.resumesRevisionAt)
        persistUploadTracking()
        objectWillChange.send()
    }

    private func persistUploadTracking() {
        Self.storeValue(uploadTracking, forKey: DefaultsKey.uploadTracking, in: defaults)
    }

    private func persistExportHistory() {
        Self.storeValue(exportHistory, forKey: DefaultsKey.exportHistory, in: defaults)
        objectWillChange.send()
    }

    private func sortResumes() {
        savedResumes.sort { lhs, rhs in
            if lhs.isPrimary != rhs.isPrimary {
                return lhs.isPrimary && !rhs.isPrimary
            }
            if lhs.lastUsedAt != rhs.lastUsedAt {
                return lhs.lastUsedAt > rhs.lastUsedAt
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func markPrimaryResume(id: UUID) {
        for index in savedResumes.indices {
            savedResumes[index].isPrimary = savedResumes[index].id == id
        }
        persistResumes()
    }

    private func touchResumeUsage(id: UUID) {
        guard let index = savedResumes.firstIndex(where: { $0.id == id }) else { return }
        savedResumes[index].lastUsedAt = .now
        savedResumes[index].uploadCount += 1
        uploadTracking[savedResumes[index].fileHash] = UploadTrackingRecord(
            fileName: savedResumes[index].originalFileName,
            count: savedResumes[index].uploadCount,
            lastUploadedAt: .now
        )
        persistResumes()
    }

    private func loadAvatarData() -> Data? {
        guard let fileName = settings.avatarFileName else { return nil }
        return try? Data(contentsOf: avatarURL(fileName: fileName), options: .mappedIfSafe)
    }

    private func normalizedDisplayName(_ candidate: String?, fallbackFileName: String) -> String {
        let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }

        let fileName = URL(fileURLWithPath: fallbackFileName).deletingPathExtension().lastPathComponent
        let cleaned = fileName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Resume" : cleaned
    }

    private func readResumeResource(from url: URL) async throws -> ProfileResumeResource {
        try await Task.detached(priority: .userInitiated) {
            try loadProfileResumeResource(from: url)
        }.value
    }

    private func ensureResumeRevisionExists() {
        guard defaults.object(forKey: DefaultsKey.resumesRevisionAt) == nil else { return }
        defaults.set(resumeSyncRevisionDate == .distantPast ? Date() : resumeSyncRevisionDate, forKey: DefaultsKey.resumesRevisionAt)
    }

    private var baseDirectoryURL: URL {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return root.appendingPathComponent("CVBoostaProfileWorkspace", isDirectory: true)
    }

    private var resumesDirectoryURL: URL {
        baseDirectoryURL.appendingPathComponent("Resumes", isDirectory: true)
    }

    private func avatarURL(fileName: String) -> URL {
        baseDirectoryURL.appendingPathComponent(fileName)
    }

    private func resumeURL(fileName: String) -> URL {
        resumesDirectoryURL.appendingPathComponent(fileName)
    }

    private func ensureDirectoryExists(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    private static func loadValue<T: Decodable>(forKey key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func storeValue<T: Encodable>(_ value: T, forKey key: String, in defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}

private extension Collection {
    func count(where predicate: (Element) throws -> Bool) rethrows -> Int {
        try reduce(into: 0) { count, element in
            if try predicate(element) {
                count += 1
            }
        }
    }
}
