import Foundation

final class CloudSyncService {
    static let shared = CloudSyncService()

    private init() {}

    func syncResumeSnapshot() async throws {
        // Tracker data now syncs across devices through the SwiftData CloudKit container.
        // Keep this hook for future non-tracker mirrors such as exported resume snapshots.
    }
}
