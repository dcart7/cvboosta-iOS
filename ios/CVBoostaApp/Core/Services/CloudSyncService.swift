import Foundation

final class CloudSyncService {
    static let shared = CloudSyncService()

    private init() {}

    func syncResumeSnapshot() async throws {
        // Placeholder: persist sync state and schedule CloudKit push.
    }
}
