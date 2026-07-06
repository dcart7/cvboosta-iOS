import Foundation
import SwiftData

struct CloudResumePayload: Hashable {
    let fileHash: String
    let resumeID: UUID
    let displayName: String
    let originalFileName: String
    let createdAt: Date
    let lastUsedAt: Date
    let uploadCount: Int
    let isPrimary: Bool
    let updatedAt: Date
    let pdfData: Data
}

@MainActor
enum WorkspaceCloudSyncService {
    static func reconcileResumes(
        modelContext: ModelContext,
        profileWorkspaceService: ProfileWorkspaceService
    ) async {
        let remoteAssets = (try? modelContext.fetch(FetchDescriptor<CloudResumeAsset>())) ?? []
        let localRevision = profileWorkspaceService.resumeSyncRevisionDate
        let remoteRevision = remoteAssets.map(\.updatedAt).max() ?? .distantPast

        guard !remoteAssets.isEmpty || !profileWorkspaceService.savedResumes.isEmpty else { return }

        if remoteAssets.isEmpty {
            await pushLocalResumes(modelContext: modelContext, profileWorkspaceService: profileWorkspaceService)
            return
        }

        if profileWorkspaceService.savedResumes.isEmpty || remoteRevision > localRevision {
            let payloads = remoteAssets.map {
                CloudResumePayload(
                    fileHash: $0.fileHash,
                    resumeID: $0.resumeID,
                    displayName: $0.displayName,
                    originalFileName: $0.originalFileName,
                    createdAt: $0.createdAt,
                    lastUsedAt: $0.lastUsedAt,
                    uploadCount: $0.uploadCount,
                    isPrimary: $0.isPrimary,
                    updatedAt: $0.updatedAt,
                    pdfData: $0.pdfData
                )
            }
            await profileWorkspaceService.applyCloudResumePayloads(payloads, syncDate: remoteRevision)
            return
        }

        if localRevision > remoteRevision {
            await pushLocalResumes(modelContext: modelContext, profileWorkspaceService: profileWorkspaceService)
        }
    }

    static func pushLocalResumes(
        modelContext: ModelContext,
        profileWorkspaceService: ProfileWorkspaceService
    ) async {
        let localRevision = profileWorkspaceService.resumeSyncRevisionDate
        let payloads = await profileWorkspaceService.exportCloudResumePayloads()
        let existingAssets = (try? modelContext.fetch(FetchDescriptor<CloudResumeAsset>())) ?? []
        let existingByHash = Dictionary(uniqueKeysWithValues: existingAssets.map { ($0.fileHash, $0) })
        let localHashes = Set(payloads.map(\.fileHash))

        for payload in payloads {
            if let existing = existingByHash[payload.fileHash] {
                existing.resumeID = payload.resumeID
                existing.displayName = payload.displayName
                existing.originalFileName = payload.originalFileName
                existing.createdAt = payload.createdAt
                existing.lastUsedAt = payload.lastUsedAt
                existing.uploadCount = payload.uploadCount
                existing.isPrimary = payload.isPrimary
                existing.updatedAt = localRevision
                existing.pdfData = payload.pdfData
            } else {
                modelContext.insert(
                    CloudResumeAsset(
                        fileHash: payload.fileHash,
                        resumeID: payload.resumeID,
                        displayName: payload.displayName,
                        originalFileName: payload.originalFileName,
                        createdAt: payload.createdAt,
                        lastUsedAt: payload.lastUsedAt,
                        uploadCount: payload.uploadCount,
                        isPrimary: payload.isPrimary,
                        updatedAt: localRevision,
                        pdfData: payload.pdfData
                    )
                )
            }
        }

        for asset in existingAssets where !localHashes.contains(asset.fileHash) {
            modelContext.delete(asset)
        }

        try? modelContext.save()
    }

    static func reconcileStreakState(modelContext: ModelContext) {
        let localSnapshot = SharedStreakState.currentSnapshot()
        let remoteState = (try? modelContext.fetch(FetchDescriptor<CloudStreakState>()))?.first

        guard remoteState != nil || !localSnapshot.isEmpty else { return }

        guard let remoteState else {
            pushLocalStreakState(modelContext: modelContext)
            return
        }

        let remoteSnapshot = SharedStreakSnapshot(
            restoreDayStamp: remoteState.restoreDayStamp,
            freezeDayStamp: remoteState.freezeDayStamp,
            updatedAt: remoteState.updatedAt
        )

        if localSnapshot.isEmpty || remoteSnapshot.updatedAt > localSnapshot.updatedAt {
            SharedStreakState.apply(snapshot: remoteSnapshot)
            return
        }

        if localSnapshot.updatedAt > remoteSnapshot.updatedAt {
            pushLocalStreakState(modelContext: modelContext)
        }
    }

    static func pushLocalStreakState(modelContext: ModelContext) {
        let localSnapshot = SharedStreakState.currentSnapshot()
        guard !localSnapshot.isEmpty else { return }

        let state = (try? modelContext.fetch(FetchDescriptor<CloudStreakState>()))?.first
            ?? CloudStreakState(
                restoreDayStamp: localSnapshot.restoreDayStamp,
                freezeDayStamp: localSnapshot.freezeDayStamp,
                updatedAt: localSnapshot.updatedAt
            )

        state.restoreDayStamp = localSnapshot.restoreDayStamp
        state.freezeDayStamp = localSnapshot.freezeDayStamp
        state.updatedAt = localSnapshot.updatedAt

        if state.modelContext == nil {
            modelContext.insert(state)
        }

        try? modelContext.save()
    }
}
