import Foundation
import SwiftData

@Model
final class CloudResumeAsset {
    @Attribute(.unique) var fileHash: String
    var resumeID: UUID
    var displayName: String
    var originalFileName: String
    var createdAt: Date
    var lastUsedAt: Date
    var uploadCount: Int
    var isPrimary: Bool
    var updatedAt: Date
    @Attribute(.externalStorage) var pdfData: Data

    init(
        fileHash: String,
        resumeID: UUID,
        displayName: String,
        originalFileName: String,
        createdAt: Date,
        lastUsedAt: Date,
        uploadCount: Int,
        isPrimary: Bool,
        updatedAt: Date,
        pdfData: Data
    ) {
        self.fileHash = fileHash
        self.resumeID = resumeID
        self.displayName = displayName
        self.originalFileName = originalFileName
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.uploadCount = uploadCount
        self.isPrimary = isPrimary
        self.updatedAt = updatedAt
        self.pdfData = pdfData
    }
}

@Model
final class CloudStreakState {
    @Attribute(.unique) var key: String
    var restoreDayStamp: String
    var freezeDayStamp: String
    var updatedAt: Date

    init(
        key: String = "shared",
        restoreDayStamp: String,
        freezeDayStamp: String,
        updatedAt: Date
    ) {
        self.key = key
        self.restoreDayStamp = restoreDayStamp
        self.freezeDayStamp = freezeDayStamp
        self.updatedAt = updatedAt
    }
}
