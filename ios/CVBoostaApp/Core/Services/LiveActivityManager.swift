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
    private var supportActivityStateTask: Task<Void, Never>?

    private let atsRegistrationStorageKey = "cvboosta.live_activity.ats.registration"
    private let atsPushToStartRegistrationStorageKey = "cvboosta.live_activity.ats.push_to_start.registration"
    private let streakCelebrationStorageKey = "cvboosta.live_activity.streak.last_seen"
    private let pipelineFingerprintStorageKey = "cvboosta.live_activity.pipeline.last_fingerprint"
    private let pipelinePresentedAtStorageKey = "cvboosta.live_activity.pipeline.last_presented_at"
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
            await restoreSupportActivityIfPossible()
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
        await restoreSupportActivityIfPossible()
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
            progress: 0.25,
            etaText: "Live progress",
            badgeText: "25%",
            compactTrailingText: "25%"
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
        let badge = percentBadge(for: progress)

        let newState = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS Analysis running",
            detail: detail,
            progress: progress,
            etaText: etaText,
            badgeText: badge,
            compactTrailingText: badge
        )

        await activity.update(.init(state: newState, staleDate: nil))
    }

    func markATSBackgrounded(progress: Double, detail: String) async {
        guard let activity = currentATSActivity else { return }
        let badge = percentBadge(for: progress)

        let newState = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS Analysis running",
            detail: detail,
            progress: progress,
            etaText: "Continuing in background",
            badgeText: badge,
            compactTrailingText: badge
        )

        await activity.update(.init(state: newState, staleDate: Date().addingTimeInterval(60 * 15)))
    }

    func end() async {
        guard let activity = currentATSActivity else { return }
        await deactivateRemoteRegistrationIfPossible(for: activity)
        await activity.end(nil, dismissalPolicy: .immediate)
        releaseATSActivity(ifMatching: activity.id)
    }

    func complete(result: ResumeScanResponse) async {
        guard let activity = currentATSActivity else { return }
        let beforeScore = result.matchBefore ?? result.atsScore
        let afterScore = result.matchAfter ?? result.atsScore
        let addedKeywordCount = result.addedKeywords.count
        let detail = addedKeywordCount > 0
            ? "+\(addedKeywordCount) keyword\(addedKeywordCount == 1 ? "" : "s") added"
            : "ATS score refined to \(afterScore)"
        let compactTrailingText = beforeScore == afterScore ? "\(afterScore)" : "\(beforeScore)->\(afterScore)"

        let completed = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "Resume optimized successfully",
            detail: detail,
            progress: 1.0,
            etaText: "Ready to export",
            badgeText: "\(afterScore)",
            compactTrailingText: compactTrailingText
        )

        await activity.update(.init(state: completed, staleDate: nil))
        await deactivateRemoteRegistrationIfPossible(for: activity)
        await activity.end(nil, dismissalPolicy: .default)
        releaseATSActivity(ifMatching: activity.id)
    }

    func celebrateDailyStreak(dayCount: Int, detail: String) async {
        let effectiveDayCount = max(dayCount, 1)
        guard shouldPresentStreakActivity(dayCount: effectiveDayCount) else { return }

        let state = CVBoostaActivityAttributes.ContentState(
            mode: .dailyStreak,
            title: "Momentum alive",
            detail: detail,
            progress: min(max(Double(effectiveDayCount) / 21.0, 0.12), 1),
            etaText: "Small wins compound",
            badgeText: "🔥 \(effectiveDayCount)d",
            compactTrailingText: "\(effectiveDayCount)d"
        )

        await upsertSupportActivity(
            attributesName: "Momentum Streak",
            state: state,
            staleDate: Date().addingTimeInterval(60 * 45),
            priority: .dailyStreak
        )
    }

    func showStreakProtection(dayCount: Int, detail: String) async {
        let effectiveDayCount = max(dayCount, 1)
        let progress = min(max(Double(effectiveDayCount) / 21.0, 0.12), 1)
        let state = CVBoostaActivityAttributes.ContentState(
            mode: .dailyStreak,
            title: "Momentum alive",
            detail: detail,
            progress: progress,
            etaText: "Applications tracked today",
            badgeText: "🔥 \(effectiveDayCount)d",
            compactTrailingText: "\(effectiveDayCount)d"
        )

        await upsertSupportActivity(
            attributesName: "Momentum Streak",
            state: state,
            staleDate: Date().addingTimeInterval(60 * 90),
            priority: .dailyStreak
        )
    }

    func showApplicationStatusUpdate(
        company: String,
        role: String,
        status: ApplicationStatus,
        fingerprint: String
    ) async {
        guard status == .interview || status == .offer else { return }
        guard shouldPresentPipelineUpdate(fingerprint: fingerprint) else { return }

        let title: String
        let badge: String
        let detail = "\(company) • \(role)"
        let footer: String
        let progress: Double

        switch status {
        case .interview:
            title = "Interview pipeline updated"
            badge = "Fresh"
            footer = "Ready for prep"
            progress = 0.74
        case .offer:
            title = "Offer pipeline updated"
            badge = "Offer"
            footer = "High-signal moment"
            progress = 1.0
        default:
            return
        }

        let state = CVBoostaActivityAttributes.ContentState(
            mode: .applicationStatus,
            title: title,
            detail: detail,
            progress: progress,
            etaText: footer,
            badgeText: badge,
            compactTrailingText: badge
        )

        await upsertSupportActivity(
            attributesName: "Pipeline Update",
            state: state,
            staleDate: Date().addingTimeInterval(status == .offer ? 60 * 90 : 60 * 45),
            priority: .applicationStatus
        )
    }

    func showInterviewCountdown(company: String, role: String, interviewAt: Date) async {
        let remaining = interviewAt.timeIntervalSinceNow
        guard remaining > 0, remaining <= 60 * 60 * 3 else {
            if currentSupportActivity == nil {
                await restoreSupportActivityIfPossible()
            }
            if currentSupportMode == .interviewCountdown {
                await clearSupportActivity()
            }
            return
        }

        let progress = max(0, min(1, 1 - (remaining / (60 * 60 * 3))))
        let countdownText = relativeCountdownText(until: interviewAt)
        let state = CVBoostaActivityAttributes.ContentState(
            mode: .interviewCountdown,
            title: "Interview starts soon",
            detail: "\(company) • \(role)",
            progress: progress,
            etaText: "Stay ready with sharp examples",
            badgeText: countdownText,
            compactTrailingText: countdownText
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
            title: "Capture the debrief",
            detail: "\(company) • \(role)",
            progress: 1,
            etaText: "While it’s fresh",
            badgeText: "Reflect",
            compactTrailingText: "Note"
        )

        await upsertSupportActivity(
            attributesName: "Interview Reflection",
            state: state,
            staleDate: Date().addingTimeInterval(60 * 90),
            priority: .postInterviewReflection
        )
    }

    func clearPostInterviewReflection() async {
        if currentSupportActivity == nil {
            await restoreSupportActivityIfPossible()
        }
        guard currentSupportMode == .postInterviewReflection else { return }
        await clearSupportActivity()
    }

    func clearInterviewCountdown() async {
        if currentSupportActivity == nil {
            await restoreSupportActivityIfPossible()
        }
        guard currentSupportMode == .interviewCountdown else { return }
        await clearSupportActivity()
    }

    func clearStreakProtection() async {
        if currentSupportActivity == nil {
            await restoreSupportActivityIfPossible()
        }
        guard currentSupportMode == .dailyStreak else { return }
        await clearSupportActivity()
    }

    func fail() async {
        guard let activity = currentATSActivity else { return }

        let failed = CVBoostaActivityAttributes.ContentState(
            mode: .atsOptimization,
            title: "ATS analysis paused",
            detail: "Please try again",
            progress: 0.0,
            etaText: "Resume scan interrupted",
            badgeText: "Retry",
            compactTrailingText: "Retry"
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

    private func restoreSupportActivityIfPossible() async {
        let supportActivities = Activity<CVBoostaActivityAttributes>.activities.filter {
            $0.content.state.mode != .atsOptimization
        }
        guard !supportActivities.isEmpty else {
            currentSupportActivity = nil
            supportActivityStateTask?.cancel()
            supportActivityStateTask = nil
            return
        }

        let preferred = supportActivities.max {
            SupportPriority(mode: $0.content.state.mode).rawValue < SupportPriority(mode: $1.content.state.mode).rawValue
        }

        guard let preferred else { return }
        bindSupportActivity(preferred)

        for activity in supportActivities where activity.id != preferred.id {
            await activity.end(nil, dismissalPolicy: .immediate)
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
            observeATSLifecycle(for: activity)
            observePushTokenUpdates(for: activity)
            await syncRemoteRegistrationIfPossible(for: activity)
            return
        }

        bindATSActivity(activity)
        await syncRemoteRegistrationIfPossible(for: activity)
    }

    private func bindATSActivity(_ activity: Activity<CVBoostaActivityAttributes>) {
        currentATSActivity = activity
        observeATSLifecycle(for: activity)
        observePushTokenUpdates(for: activity)
    }

    private func bindSupportActivity(_ activity: Activity<CVBoostaActivityAttributes>) {
        currentSupportActivity = activity
        observeSupportLifecycle(for: activity)
    }

    private func observeATSLifecycle(for activity: Activity<CVBoostaActivityAttributes>) {
        atsActivityStateTask?.cancel()
        atsActivityStateTask = Task { [weak self] in
            guard let self else { return }

            for await state in activity.activityStateUpdates {
                if Task.isCancelled {
                    return
                }

                switch state {
                case .dismissed, .ended:
                    self.handleEndedATSActivity(activityID: activity.id)
                    return
                default:
                    continue
                }
            }
        }
    }

    private func observeSupportLifecycle(for activity: Activity<CVBoostaActivityAttributes>) {
        supportActivityStateTask?.cancel()
        supportActivityStateTask = Task { [weak self] in
            guard let self else { return }

            for await state in activity.activityStateUpdates {
                if Task.isCancelled {
                    return
                }

                switch state {
                case .dismissed, .ended:
                    self.handleEndedSupportActivity(activityID: activity.id)
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

    private func handleEndedSupportActivity(activityID: String) {
        releaseSupportActivity(ifMatching: activityID)
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

    private func releaseSupportActivity(ifMatching activityID: String) {
        guard currentSupportActivity?.id == activityID else { return }
        currentSupportActivity = nil
        supportActivityStateTask?.cancel()
        supportActivityStateTask = nil
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

    private func shouldPresentStreakActivity(dayCount: Int) -> Bool {
        let today = Calendar.current.startOfDay(for: .now)
        if let snapshot = defaults.dictionary(forKey: streakCelebrationStorageKey),
           let timestamp = snapshot["date"] as? TimeInterval,
           let storedDayCount = snapshot["dayCount"] as? Int {
            let storedDate = Date(timeIntervalSince1970: timestamp)
            if Calendar.current.isDate(storedDate, inSameDayAs: today), storedDayCount >= dayCount {
                return false
            }
        }

        defaults.set(
            [
                "date": today.timeIntervalSince1970,
                "dayCount": dayCount
            ],
            forKey: streakCelebrationStorageKey
        )
        return true
    }

    private func shouldPresentPipelineUpdate(fingerprint: String) -> Bool {
        let lastFingerprint = defaults.string(forKey: pipelineFingerprintStorageKey)
        let lastPresentedAt = defaults.object(forKey: pipelinePresentedAtStorageKey) as? Date

        if lastFingerprint == fingerprint,
           let lastPresentedAt,
           Date().timeIntervalSince(lastPresentedAt) < 60 * 60 * 4 {
            return false
        }

        defaults.set(fingerprint, forKey: pipelineFingerprintStorageKey)
        defaults.set(Date(), forKey: pipelinePresentedAtStorageKey)
        return true
    }

    private func percentBadge(for progress: Double) -> String {
        "\(Int(min(max(progress, 0), 1) * 100))%"
    }

    private func relativeCountdownText(until date: Date) -> String {
        let totalMinutes = max(Int(date.timeIntervalSinceNow / 60), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours <= 0 {
            return "In \(minutes)m"
        }

        return String(format: "In %dh %02dm", hours, minutes)
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
        if currentSupportActivity == nil {
            await restoreSupportActivityIfPossible()
        }

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
            releaseSupportActivity(ifMatching: activity.id)
        }

        do {
            let attributes = CVBoostaActivityAttributes(activityName: attributesName)
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: staleDate)
            )
            bindSupportActivity(activity)
        } catch {
            print("Failed to start support live activity: \(error)")
        }
    }

    private func clearSupportActivity() async {
        if currentSupportActivity == nil {
            await restoreSupportActivityIfPossible()
        }
        guard let activity = currentSupportActivity else { return }
        await activity.end(nil, dismissalPolicy: .default)
        releaseSupportActivity(ifMatching: activity.id)
    }
}

@available(iOS 16.1, *)
private enum SupportPriority: Int {
    case dailyStreak = 0
    case applicationStatus = 1
    case interviewCountdown = 2
    case postInterviewReflection = 3

    init(mode: CVBoostaActivityAttributes.ActivityMode) {
        switch mode {
        case .dailyStreak:
            self = .dailyStreak
        case .applicationStatus:
            self = .applicationStatus
        case .interviewCountdown:
            self = .interviewCountdown
        case .postInterviewReflection:
            self = .postInterviewReflection
        default:
            self = .dailyStreak
        }
    }
}
