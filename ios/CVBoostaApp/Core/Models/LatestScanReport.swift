import Foundation
import SwiftData

@Model
final class LatestScanReport {
    // Singleton row used by Tailoring Preview and other companion features.
    @Attribute(.unique) var id: String
    var updatedAt: Date
    @Attribute(.externalStorage) var payloadJSON: Data

    init(
        id: String = "latest",
        updatedAt: Date = .now,
        payloadJSON: Data
    ) {
        self.id = id
        self.updatedAt = updatedAt
        self.payloadJSON = payloadJSON
    }
}

/// Codable snapshot of the latest scan so other tabs can render companion previews.
struct LatestScanPayload: Codable, Hashable {
    let updatedAt: Date
    let isDemo: Bool
    let resumeName: String
    let targetRole: String
    let experienceLevel: String
    let targetMarket: String
    let response: ResumeScanResponse
}

extension LatestScanPayload {
    init(from result: ResumeScanResult, updatedAt: Date = .now) {
        self.updatedAt = updatedAt
        self.isDemo = result.isDemo
        self.resumeName = result.resumeName
        self.targetRole = result.targetRole
        self.experienceLevel = result.experienceLevel
        self.targetMarket = result.targetMarket
        self.response = result.response
    }
}
