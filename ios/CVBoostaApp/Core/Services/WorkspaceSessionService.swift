import Foundation
import SwiftData

enum WorkspaceSessionKind: String, CaseIterable, Codable, Equatable {
    case scanner
    case tailoring

    var title: String {
        switch self {
        case .scanner: return "Scanner"
        case .tailoring: return "Tailoring"
        }
    }
}

struct WorkspaceSessionSnapshot: Codable, Equatable {
    let id: UUID
    let kind: WorkspaceSessionKind
    let startedAt: Date
    let updatedAt: Date
    let expiresAt: Date

    var remainingTime: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }
}

@MainActor
final class WorkspaceSessionService: ObservableObject {
    static let shared = WorkspaceSessionService()
    static let sessionLifetime: TimeInterval = 60 * 60

    @Published private(set) var scannerSession: WorkspaceSessionSnapshot?
    @Published private(set) var tailoringSession: WorkspaceSessionSnapshot?

    private let defaults = UserDefaults.standard

    init() {
        reload()
    }

    func snapshot(for kind: WorkspaceSessionKind) -> WorkspaceSessionSnapshot? {
        switch kind {
        case .scanner: return scannerSession
        case .tailoring: return tailoringSession
        }
    }

    @discardableResult
    func ensureSession(for kind: WorkspaceSessionKind) -> WorkspaceSessionSnapshot {
        if resetIfExpired(kind) {
            return startNewSession(for: kind)
        }

        if let existing = snapshot(for: kind) {
            return existing
        }

        return startNewSession(for: kind)
    }

    @discardableResult
    func startNewSession(for kind: WorkspaceSessionKind) -> WorkspaceSessionSnapshot {
        let now = Date()
        let session = WorkspaceSessionSnapshot(
            id: UUID(),
            kind: kind,
            startedAt: now,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(Self.sessionLifetime)
        )
        save(session, for: kind)
        return session
    }

    func touch(_ kind: WorkspaceSessionKind) {
        let now = Date()
        let current = snapshot(for: kind)
        let session = WorkspaceSessionSnapshot(
            id: current?.id ?? UUID(),
            kind: kind,
            startedAt: current?.startedAt ?? now,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(Self.sessionLifetime)
        )
        save(session, for: kind)
    }

    @discardableResult
    func resetIfExpired(_ kind: WorkspaceSessionKind) -> Bool {
        guard let existing = snapshot(for: kind) else {
            return false
        }

        guard existing.expiresAt <= Date() else {
            return false
        }

        clear(kind)
        return true
    }

    func clear(_ kind: WorkspaceSessionKind) {
        defaults.removeObject(forKey: storageKey(for: kind))
        apply(nil, for: kind)
    }

    func formattedRemainingTime(for kind: WorkspaceSessionKind) -> String {
        guard let snapshot = snapshot(for: kind) else {
            return "No active session"
        }

        let remaining = max(Int(snapshot.remainingTime), 0)
        let minutes = remaining / 60
        let hours = minutes / 60

        if hours > 0 {
            return "\(hours)h \(minutes % 60)m left"
        }
        return "\(minutes)m left"
    }

    func reload() {
        for kind in WorkspaceSessionKind.allCases {
            guard
                let data = defaults.data(forKey: storageKey(for: kind)),
                let session = try? JSONDecoder().decode(WorkspaceSessionSnapshot.self, from: data)
            else {
                apply(nil, for: kind)
                continue
            }

            apply(session, for: kind)
        }
    }

    private func save(_ session: WorkspaceSessionSnapshot, for kind: WorkspaceSessionKind) {
        if let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: storageKey(for: kind))
        }
        apply(session, for: kind)
    }

    private func apply(_ session: WorkspaceSessionSnapshot?, for kind: WorkspaceSessionKind) {
        switch kind {
        case .scanner:
            scannerSession = session
        case .tailoring:
            tailoringSession = session
        }
    }

    private func storageKey(for kind: WorkspaceSessionKind) -> String {
        "cvboosta.workspaceSession.\(kind.rawValue)"
    }
}

enum LatestScanCacheStore {
    @MainActor
    static func persist(result: ResumeScanResult, in modelContext: ModelContext) throws {
        let payload = LatestScanPayload(from: result)
        let data = try JSONEncoder().encode(payload)

        let descriptor = FetchDescriptor<LatestScanReport>(
            predicate: #Predicate { $0.id == "latest" }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.updatedAt = payload.updatedAt
            existing.payloadJSON = data
        } else {
            modelContext.insert(
                LatestScanReport(
                    updatedAt: payload.updatedAt,
                    payloadJSON: data
                )
            )
        }

        try modelContext.save()
        WorkspaceSessionService.shared.touch(.tailoring)
    }

    @MainActor
    static func clear(in modelContext: ModelContext) {
        let descriptor = FetchDescriptor<LatestScanReport>(
            predicate: #Predicate { $0.id == "latest" }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }
}
