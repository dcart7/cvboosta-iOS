import ActivityKit
import Foundation

private struct LiveActivityAPNSTokenRequest: Encodable {
    let activityID: String
    let token: String
    let bundleID: String
    let apnsEnvironment: String
    let mode: String
    let attributesType: String

    enum CodingKeys: String, CodingKey {
        case activityID = "activity_id"
        case token
        case bundleID = "bundle_id"
        case apnsEnvironment = "apns_environment"
        case mode
        case attributesType = "attributes_type"
    }
}

private struct LiveActivityPushToStartTokenRequest: Encodable {
    let token: String
    let bundleID: String
    let apnsEnvironment: String
    let mode: String
    let attributesType: String

    enum CodingKeys: String, CodingKey {
        case token
        case bundleID = "bundle_id"
        case apnsEnvironment = "apns_environment"
        case mode
        case attributesType = "attributes_type"
    }
}

private struct LiveActivityRegisterResponse: Decodable {
    let message: String?
}

private struct LiveActivityRegistrationSnapshot: Codable {
    let activityID: String
    let token: String
    let bundleID: String
    let apnsEnvironment: String
    let mode: String
    let attributesType: String
}

private struct LiveActivityPushToStartRegistrationSnapshot: Codable {
    let token: String
    let bundleID: String
    let apnsEnvironment: String
    let mode: String
    let attributesType: String
}

@MainActor
@available(iOS 16.1, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private let client: AuthenticatedAPIClient
    private let defaults: UserDefaults

    private var currentATSActivity: Activity<CVBoostaActivityAttributes>?
    private var currentSupportActivity: Activity<CVBoostaActivityAttributes>?
    private var atsPushTokenTask: Task<Void, Never>?
    private var atsPushToStartTokenTask: Task<Void, Never>?
    private var atsActivityUpdatesTask: Task<Void, Never>?
    private var atsActivityStateTask: Task<Void, Never>?

    private let atsRegistrationStorageKey = "cvboosta.live_activity.ats.registration"
    private let atsPushToStartRegistrationStorageKey = "cvboosta.live_activity.ats.push_to_start.registration"
    private let attributesTypeName = "CVBoostaActivityAttributes"

    private init(
        client: AuthenticatedAPIClient = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.defaults = defaults
    }

    func configure() {
        Task {
            observeATSActivityUpdates()
            if #available(iOS 17.2, *) {
                observePushToStartTokenUpdates()
            }
            await restoreATSActivityIfPossible()
            await syncRemoteStateIfPossible()
        }
    }

    func syncRemoteStateIfPossible() async {
        observeATSActivityUpdates()
        if #available(iOS 17.2, *) {
            observePushToStartTokenUpdates()
            await syncPushToStartRegistrationIfPossible()
        }

        await restoreATSActivityIfPossible()
        guard let activity = currentATSActivity else { return }
        observePushTokenUpdates(for: activity)
        await syncRemoteRegistrationIfPossible(for: activity)
    }

    func deactivateRemoteStateIfPossible() async {
        if let activity = currentATSActivity {
            await deactivateRemoteRegistrationIfPossible(for: activity)
        } else {
            await deactivateStoredATSRegistrationIfPossible()
        }

        if #available(iOS 17.2, *) {
            await deactivatePushToStartRegistrationIfPossible()
        }
    }

    func startATSOptimization(title: String, detail: String) async {
        let attributes = CVBoostaActivityAttributes(activityName: "ATS Analysis")
        let state = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: title,
            detail: detail,
            progress: 0.05,
            etaText: "Preparing"
        )

        do {
            if let currentATSActivity {
                await deactivateRemoteRegistrationIfPossible(for: currentATSActivity)
                await currentATSActivity.end(nil, dismissalPolicy: .immediate)
                releaseATSActivity(ifMatching: currentATSActivity.id)
            }

            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: Date().addingTimeInterval(60 * 10)),
                pushType: .token
            )
            bindATSActivity(activity)
            await syncRemoteRegistrationIfPossible(for: activity)
        } catch {
            print("Failed to start live activity: \(error)")
        }
    }

    func update(progress: Double, detail: String, etaText: String) async {
        guard let activity = currentATSActivity else { return }

        let newState = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS Analysis",
            detail: detail,
            progress: progress,
            etaText: etaText
        )

        await activity.update(.init(state: newState, staleDate: nil))
    }

    func markATSBackgrounded(progress: Double, detail: String) async {
        guard let activity = currentATSActivity else { return }

        let newState = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS Analysis running",
            detail: detail,
            progress: progress,
            etaText: "Continuing in background"
        )

        await activity.update(.init(state: newState, staleDate: Date().addingTimeInterval(60 * 15)))
    }

    func end() async {
        guard let activity = currentATSActivity else { return }
        await deactivateRemoteRegistrationIfPossible(for: activity)
        await activity.end(nil, dismissalPolicy: .immediate)
        releaseATSActivity(ifMatching: activity.id)
    }

    func complete(finalScore: Int) async {
        guard let activity = currentATSActivity else { return }

        let completed = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS Analysis complete",
            detail: "Final score: \(finalScore)",
            progress: 1.0,
            etaText: ""
        )

        await activity.update(.init(state: completed, staleDate: nil))
        await deactivateRemoteRegistrationIfPossible(for: activity)
        await activity.end(nil, dismissalPolicy: .default)
        releaseATSActivity(ifMatching: activity.id)
    }

    func celebrateDailyStreak(dayCount: Int, detail: String) async {
        let attributes = CVBoostaActivityAttributes(activityName: "Career Streak")
        let state = CVBoostaActivityAttributes.ContentState(
            mode: .dailyStreak,
            title: dayCount == 0 ? "Momentum started" : "Career streak active",
            detail: detail,
            progress: min(max(Double(dayCount) / 30.0, 0.08), 1),
            etaText: dayCount == 0 ? "Day 1" : "\(dayCount) days"
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: Date().addingTimeInterval(60 * 5))
            )
            await activity.end(nil, dismissalPolicy: .default)
        } catch {
            print("Failed to celebrate streak activity: \(error)")
        }
    }

    func showStreakProtection(dayCount: Int, detail: String) async {
        let progress = min(max(Double(dayCount) / 30.0, 0.08), 1)
        let state = CVBoostaActivityAttributes.ContentState(
            mode: .dailyStreak,
            title: "Weekly consistency goal",
            detail: detail,
            progress: progress,
            etaText: dayCount == 0 ? "1 / 1 day" : "\(min(dayCount, 5)) / 5 days"
        )

        await upsertSupportActivity(
            attributesName: "Streak Protection",
            state: state,
            staleDate: Date().addingTimeInterval(60 * 90),
            priority: .dailyStreak
        )
    }

    func showInterviewCountdown(company: String, role: String, interviewAt: Date) async {
        let remaining = interviewAt.timeIntervalSinceNow
        guard remaining > 0, remaining <= 60 * 60 * 3 else {
            if currentSupportMode == .interviewCountdown {
                await clearSupportActivity()
            }
            return
        }

        let progress = max(0, min(1, 1 - (remaining / (60 * 60 * 3))))
        let state = CVBoostaActivityAttributes.ContentState(
            mode: .interviewCountdown,
            title: company,
            detail: role,
            progress: progress,
            etaText: interviewAt.formatted(date: .omitted, time: .shortened)
        )

        await upsertSupportActivity(
            attributesName: "Interview Countdown",
            state: state,
            staleDate: interviewAt.addingTimeInterval(60 * 30),
            priority: .interviewCountdown
        )
    }

    func showPostInterviewReflection(company: String, role: String) async {
        let state = CVBoostaActivityAttributes.ContentState(
            mode: .postInterviewReflection,
            title: "Log how it went",
            detail: "\(company) • \(role)",
            progress: 1,
            etaText: "While it’s fresh"
        )

        await upsertSupportActivity(
            attributesName: "Interview Reflection",
            state: state,
            staleDate: Date().addingTimeInterval(60 * 90),
            priority: .postInterviewReflection
        )
    }

    func clearPostInterviewReflection() async {
        guard currentSupportMode == .postInterviewReflection else { return }
        await clearSupportActivity()
    }

    func clearInterviewCountdown() async {
        guard currentSupportMode == .interviewCountdown else { return }
        await clearSupportActivity()
    }

    func clearStreakProtection() async {
        guard currentSupportMode == .dailyStreak else { return }
        await clearSupportActivity()
    }

    func fail() async {
        guard let activity = currentATSActivity else { return }

        let failed = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS Analysis failed",
            detail: "Please try again",
            progress: 0.0,
            etaText: ""
        )

        await activity.update(.init(state: failed, staleDate: nil))
        await deactivateRemoteRegistrationIfPossible(for: activity)
        await activity.end(nil, dismissalPolicy: .default)
        releaseATSActivity(ifMatching: activity.id)
    }

    private var currentSupportMode: CVBoostaActivityAttributes.ActivityMode? {
        currentSupportActivity?.content.state.mode
    }

    private func restoreATSActivityIfPossible() async {
        guard currentATSActivity == nil else { return }
        if let activity = Activity<CVBoostaActivityAttributes>.activities.first(where: { $0.content.state.mode == .atsOptimization }) {
            bindATSActivity(activity)
        }
    }

    private func observeATSActivityUpdates() {
        guard atsActivityUpdatesTask == nil else { return }

        atsActivityUpdatesTask = Task { [weak self] in
            guard let self else { return }

            for await activity in Activity<CVBoostaActivityAttributes>.activityUpdates {
                if Task.isCancelled {
                    return
                }
                guard activity.content.state.mode == .atsOptimization else {
                    continue
                }
                await self.handleObservedATSActivity(activity)
            }
        }
    }

    private func handleObservedATSActivity(_ activity: Activity<CVBoostaActivityAttributes>) async {
        if currentATSActivity?.id == activity.id {
            observeActivityLifecycle(for: activity)
            observePushTokenUpdates(for: activity)
            await syncRemoteRegistrationIfPossible(for: activity)
            return
        }

        bindATSActivity(activity)
        await syncRemoteRegistrationIfPossible(for: activity)
    }

    private func bindATSActivity(_ activity: Activity<CVBoostaActivityAttributes>) {
        currentATSActivity = activity
        observeActivityLifecycle(for: activity)
        observePushTokenUpdates(for: activity)
    }

    private func observeActivityLifecycle(for activity: Activity<CVBoostaActivityAttributes>) {
        atsActivityStateTask?.cancel()
        atsActivityStateTask = Task { [weak self] in
            guard let self else { return }

            for await state in activity.activityStateUpdates {
                if Task.isCancelled {
                    return
                }

                switch state {
                case .dismissed, .ended:
                    await self.handleEndedATSActivity(activityID: activity.id)
                    return
                default:
                    continue
                }
            }
        }
    }

    private func handleEndedATSActivity(activityID: String) {
        releaseATSActivity(ifMatching: activityID)
    }

    private func releaseATSActivity(ifMatching activityID: String) {
        guard currentATSActivity?.id == activityID else { return }
        currentATSActivity = nil
        atsPushTokenTask?.cancel()
        atsPushTokenTask = nil
        atsActivityStateTask?.cancel()
        atsActivityStateTask = nil
        clearStoredATSRegistration()
    }

    private func observePushTokenUpdates(for activity: Activity<CVBoostaActivityAttributes>) {
        guard activity.content.state.mode == .atsOptimization else { return }

        atsPushTokenTask?.cancel()
        atsPushTokenTask = Task { [weak self] in
            guard let self else { return }

            if let existingToken = activity.pushToken {
                await self.registerRemoteToken(for: activity, pushToken: existingToken)
            }

            for await pushToken in activity.pushTokenUpdates {
                if Task.isCancelled {
                    return
                }
                await self.registerRemoteToken(for: activity, pushToken: pushToken)
            }
        }
    }

    private func registerRemoteToken(
        for activity: Activity<CVBoostaActivityAttributes>,
        pushToken: Data
    ) async {
        guard let path = liveActivityRegisterPath else { return }

        let tokenString = hexString(from: pushToken)
        let snapshot = makeSnapshot(for: activity, token: tokenString)
        storeATSRegistration(snapshot)
        print("Live Activity push token [\(activity.id)]: \(tokenString)")

        do {
            let _: LiveActivityRegisterResponse = try await client.postJSON(
                path: path,
                body: makeRemoteRequestBody(from: snapshot)
            )
        } catch {
            // Best effort. We retry on the next app launch/login/token refresh.
        }
    }

    private func syncRemoteRegistrationIfPossible(for activity: Activity<CVBoostaActivityAttributes>) async {
        guard activity.content.state.mode == .atsOptimization else { return }

        if let pushToken = activity.pushToken {
            await registerRemoteToken(for: activity, pushToken: pushToken)
            return
        }

        guard let path = liveActivityRegisterPath,
              let snapshot = storedATSRegistration(),
              snapshot.activityID == activity.id
        else { return }

        do {
            let _: LiveActivityRegisterResponse = try await client.postJSON(
                path: path,
                body: makeRemoteRequestBody(from: snapshot)
            )
        } catch {
            // Best effort. We retry after the next successful auth/bootstrap.
        }
    }

    private func deactivateStoredATSRegistrationIfPossible() async {
        guard let path = liveActivityDeactivatePath,
              let snapshot = storedATSRegistration()
        else {
            clearStoredATSRegistration()
            return
        }

        do {
            let _: LiveActivityRegisterResponse = try await client.postJSON(
                path: path,
                body: makeRemoteRequestBody(from: snapshot)
            )
        } catch {
            // Best effort. Stale backend tokens are harmless and will be cleaned up on failure.
        }

        clearStoredATSRegistration()
    }

    private func deactivateRemoteRegistrationIfPossible(
        for activity: Activity<CVBoostaActivityAttributes>
    ) async {
        atsPushTokenTask?.cancel()
        atsPushTokenTask = nil

        guard let path = liveActivityDeactivatePath else {
            clearStoredATSRegistration()
            return
        }

        guard let snapshot = registrationSnapshot(for: activity) else {
            clearStoredATSRegistration()
            return
        }

        do {
            let _: LiveActivityRegisterResponse = try await client.postJSON(
                path: path,
                body: makeRemoteRequestBody(from: snapshot)
            )
        } catch {
            // Best effort. Local activity still ends even if backend cleanup fails.
        }

        clearStoredATSRegistration()
    }

    private func registrationSnapshot(
        for activity: Activity<CVBoostaActivityAttributes>
    ) -> LiveActivityRegistrationSnapshot? {
        if let stored = storedATSRegistration(), stored.activityID == activity.id {
            return stored
        }

        if let pushToken = activity.pushToken {
            return makeSnapshot(for: activity, token: hexString(from: pushToken))
        }

        return nil
    }

    @available(iOS 17.2, *)
    private func observePushToStartTokenUpdates() {
        guard atsPushToStartTokenTask == nil else { return }

        atsPushToStartTokenTask = Task { [weak self] in
            guard let self else { return }

            if let existingToken = Activity<CVBoostaActivityAttributes>.pushToStartToken {
                await self.registerPushToStartToken(existingToken)
            }

            for await pushToken in Activity<CVBoostaActivityAttributes>.pushToStartTokenUpdates {
                if Task.isCancelled {
                    return
                }
                await self.registerPushToStartToken(pushToken)
            }
        }
    }

    @available(iOS 17.2, *)
    private func registerPushToStartToken(_ pushToken: Data) async {
        guard let path = liveActivityPushToStartRegisterPath else { return }

        let tokenString = hexString(from: pushToken)
        let snapshot = makePushToStartSnapshot(token: tokenString)
        storeATSPushToStartRegistration(snapshot)
        print("Live Activity push-to-start token: \(tokenString)")

        do {
            let _: LiveActivityRegisterResponse = try await client.postJSON(
                path: path,
                body: makePushToStartRequestBody(from: snapshot)
            )
        } catch {
            // Best effort. We retry on the next app launch/login/token refresh.
        }
    }

    @available(iOS 17.2, *)
    private func syncPushToStartRegistrationIfPossible() async {
        if let pushToken = Activity<CVBoostaActivityAttributes>.pushToStartToken {
            await registerPushToStartToken(pushToken)
            return
        }

        guard let path = liveActivityPushToStartRegisterPath,
              let snapshot = storedATSPushToStartRegistration()
        else { return }

        do {
            let _: LiveActivityRegisterResponse = try await client.postJSON(
                path: path,
                body: makePushToStartRequestBody(from: snapshot)
            )
        } catch {
            // Best effort. We retry after the next successful auth/bootstrap.
        }
    }

    @available(iOS 17.2, *)
    private func deactivatePushToStartRegistrationIfPossible() async {
        guard let path = liveActivityPushToStartDeactivatePath else {
            clearStoredATSPushToStartRegistration()
            return
        }

        let snapshot: LiveActivityPushToStartRegistrationSnapshot?
        if let stored = storedATSPushToStartRegistration() {
            snapshot = stored
        } else if let token = Activity<CVBoostaActivityAttributes>.pushToStartToken {
            snapshot = makePushToStartSnapshot(token: hexString(from: token))
        } else {
            snapshot = nil
        }

        guard let snapshot else {
            clearStoredATSPushToStartRegistration()
            return
        }

        do {
            let _: LiveActivityRegisterResponse = try await client.postJSON(
                path: path,
                body: makePushToStartRequestBody(from: snapshot)
            )
        } catch {
            // Best effort. Future login/bootstrap will refresh the token anyway.
        }

        clearStoredATSPushToStartRegistration()
    }

    private func makeSnapshot(
        for activity: Activity<CVBoostaActivityAttributes>,
        token: String
    ) -> LiveActivityRegistrationSnapshot {
        LiveActivityRegistrationSnapshot(
            activityID: activity.id,
            token: token,
            bundleID: Bundle.main.bundleIdentifier ?? AppEnvironment.appBundleIdentifierPlaceholder,
            apnsEnvironment: AppEnvironment.apnsEnvironment.rawValue,
            mode: activity.content.state.mode.rawValue,
            attributesType: attributesTypeName
        )
    }

    private func makePushToStartSnapshot(token: String) -> LiveActivityPushToStartRegistrationSnapshot {
        LiveActivityPushToStartRegistrationSnapshot(
            token: token,
            bundleID: Bundle.main.bundleIdentifier ?? AppEnvironment.appBundleIdentifierPlaceholder,
            apnsEnvironment: AppEnvironment.apnsEnvironment.rawValue,
            mode: CVBoostaActivityAttributes.ActivityMode.atsOptimization.rawValue,
            attributesType: attributesTypeName
        )
    }

    private func makeRemoteRequestBody(
        from snapshot: LiveActivityRegistrationSnapshot
    ) -> LiveActivityAPNSTokenRequest {
        LiveActivityAPNSTokenRequest(
            activityID: snapshot.activityID,
            token: snapshot.token,
            bundleID: snapshot.bundleID,
            apnsEnvironment: snapshot.apnsEnvironment,
            mode: snapshot.mode,
            attributesType: snapshot.attributesType
        )
    }

    private func makePushToStartRequestBody(
        from snapshot: LiveActivityPushToStartRegistrationSnapshot
    ) -> LiveActivityPushToStartTokenRequest {
        LiveActivityPushToStartTokenRequest(
            token: snapshot.token,
            bundleID: snapshot.bundleID,
            apnsEnvironment: snapshot.apnsEnvironment,
            mode: snapshot.mode,
            attributesType: snapshot.attributesType
        )
    }

    private func storeATSRegistration(_ snapshot: LiveActivityRegistrationSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: atsRegistrationStorageKey)
    }

    private func storedATSRegistration() -> LiveActivityRegistrationSnapshot? {
        guard let data = defaults.data(forKey: atsRegistrationStorageKey) else { return nil }
        return try? JSONDecoder().decode(LiveActivityRegistrationSnapshot.self, from: data)
    }

    private func clearStoredATSRegistration() {
        defaults.removeObject(forKey: atsRegistrationStorageKey)
    }

    private func storeATSPushToStartRegistration(_ snapshot: LiveActivityPushToStartRegistrationSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: atsPushToStartRegistrationStorageKey)
    }

    private func storedATSPushToStartRegistration() -> LiveActivityPushToStartRegistrationSnapshot? {
        guard let data = defaults.data(forKey: atsPushToStartRegistrationStorageKey) else { return nil }
        return try? JSONDecoder().decode(LiveActivityPushToStartRegistrationSnapshot.self, from: data)
    }

    private func clearStoredATSPushToStartRegistration() {
        defaults.removeObject(forKey: atsPushToStartRegistrationStorageKey)
    }

    private func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private var liveActivityRegisterPath: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "LIVE_ACTIVITY_REGISTER_PATH") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var liveActivityDeactivatePath: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "LIVE_ACTIVITY_DEACTIVATE_PATH") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var liveActivityPushToStartRegisterPath: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "LIVE_ACTIVITY_PUSH_TO_START_REGISTER_PATH") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var liveActivityPushToStartDeactivatePath: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "LIVE_ACTIVITY_PUSH_TO_START_DEACTIVATE_PATH") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func upsertSupportActivity(
        attributesName: String,
        state: CVBoostaActivityAttributes.ContentState,
        staleDate: Date?,
        priority: SupportPriority
    ) async {
        if let currentSupportMode {
            let currentPriority = SupportPriority(mode: currentSupportMode)
            guard priority.rawValue >= currentPriority.rawValue || currentSupportMode == state.mode else {
                return
            }
        }

        if let activity = currentSupportActivity, activity.content.state.mode == state.mode {
            await activity.update(.init(state: state, staleDate: staleDate))
            return
        }

        if let activity = currentSupportActivity {
            await activity.end(nil, dismissalPolicy: .default)
            currentSupportActivity = nil
        }

        do {
            let attributes = CVBoostaActivityAttributes(activityName: attributesName)
            currentSupportActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: staleDate)
            )
        } catch {
            print("Failed to start support live activity: \(error)")
        }
    }

    private func clearSupportActivity() async {
        guard let activity = currentSupportActivity else { return }
        await activity.end(nil, dismissalPolicy: .default)
        currentSupportActivity = nil
    }
}

@available(iOS 16.1, *)
private enum SupportPriority: Int {
    case dailyStreak = 0
    case interviewCountdown = 1
    case postInterviewReflection = 2

    init(mode: CVBoostaActivityAttributes.ActivityMode) {
        switch mode {
        case .dailyStreak:
            self = .dailyStreak
        case .interviewCountdown:
            self = .interviewCountdown
        case .postInterviewReflection:
            self = .postInterviewReflection
        default:
            self = .dailyStreak
        }
    }
}
