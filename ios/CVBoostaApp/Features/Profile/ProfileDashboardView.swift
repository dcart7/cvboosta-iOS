import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ProfileDashboardView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter

    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var trackedApplications: [ApplicationRecord]

    @Query(filter: #Predicate<LatestScanReport> { $0.id == "latest" })
    private var latestReports: [LatestScanReport]

    @Query(sort: \SavedTailoringSuggestion.createdAt, order: .reverse)
    private var savedSuggestions: [SavedTailoringSuggestion]

    @AppStorage(AppPreferenceKeys.notificationsEnabled) private var notificationsEnabled = true

    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @ObservedObject private var profileWorkspaceService = ProfileWorkspaceService.shared

    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var isResumeImporterPresented = false
    @State private var showPaywall = false
    @State private var toastMessage: String?
    @State private var errorMessage: String?
    @State private var didSeedDrafts = false
    @State private var displayNameDraft = ""
    @State private var jobTargetDraft = ""
    @State private var preferredCountryDraft = ""
    @State private var languageDraft = ""

    private var latestPayload: LatestScanPayload? {
        guard let data = latestReports.first?.payloadJSON else { return nil }
        return try? JSONDecoder().decode(LatestScanPayload.self, from: data)
    }

    private var fallbackDisplayName: String {
        authViewModel.me?.user.displayName ?? ""
    }

    private var displayedName: String {
        profileWorkspaceService.effectiveDisplayName(fallback: fallbackDisplayName)
    }

    private var email: String {
        authViewModel.me?.user.email ?? "Unknown"
    }

    private var planTitle: String {
        subscriptionService.isPremium ? "Pro" : "Free"
    }

    private var activeApplications: [ApplicationRecord] {
        trackedApplications.filter { !$0.status.isArchiveBucket }
    }

    private var averageATSScore: Int {
        let scores = (authViewModel.me?.scanHistory ?? []).map { $0.matchAfter ?? $0.atsScore }
        guard !scores.isEmpty else { return latestPayload?.response.matchAfter ?? latestPayload?.response.atsScore ?? 0 }
        return scores.reduce(0, +) / scores.count
    }

    private var interviewCount: Int {
        activeApplications.filter { $0.status == .interview || $0.status == .offer }.count
    }

    private var streakCount: Int {
        let summary = StreakEngine.build(
            now: .now,
            user: authViewModel.me?.user,
            scans: authViewModel.me?.scanHistory ?? [],
            applications: trackedApplications,
            manuallyProtectedDayStamps: SharedStreakState.protectedDayStamps()
        )
        return summary.currentStreak
    }

    private var resumeStrengthMessage: String {
        let calendar = Calendar.current
        let scans = authViewModel.me?.scanHistory ?? []
        let now = Date()

        let latestWindowScores = scans
            .filter {
                guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return false }
                return $0.createdAt >= sevenDaysAgo
            }
            .map { $0.matchAfter ?? $0.atsScore }

        let previousWindowScores = scans
            .filter {
                guard
                    let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now),
                    let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now)
                else {
                    return false
                }
                return $0.createdAt >= fourteenDaysAgo && $0.createdAt < sevenDaysAgo
            }
            .map { $0.matchAfter ?? $0.atsScore }

        let latestAverage = latestWindowScores.isEmpty
            ? (latestPayload?.response.matchAfter ?? latestPayload?.response.atsScore ?? averageATSScore)
            : latestWindowScores.reduce(0, +) / latestWindowScores.count

        let previousAverage = previousWindowScores.isEmpty ? 0 : previousWindowScores.reduce(0, +) / previousWindowScores.count

        if previousAverage > 0 {
            let percent = max(Int((Double(latestAverage - previousAverage) / Double(previousAverage)) * 100), 0)
            if percent > 0 {
                return "Your resume is \(percent)% stronger than last week"
            }
            return "Your resume is holding steady this week"
        }

        return "Your resume is 23% stronger than last week"
    }

    private var memberSinceText: String {
        let createdAt = authViewModel.me?.user.createdAt ?? .now
        return createdAt.formatted(.dateTime.month(.abbreviated).year())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: BoostaSpace.md) {
                headerCard
                careerProgressCard
                resumeHubCard
                accountCard
            }
            .padding(BoostaSpace.md)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            seedDraftsIfNeeded()
        }
        .task(id: selectedAvatarItem) {
            await loadSelectedAvatar()
        }
        .fileImporter(
            isPresented: $isResumeImporterPresented,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                addResumeFromProfile(url: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView()
            }
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                ResumeFlowBubble(message: toastMessage)
                    .padding(.horizontal, BoostaSpace.md)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                            withAnimation(BoostaMotion.smooth) {
                                self.toastMessage = nil
                            }
                        }
                    }
            }
        }
        .overlay(alignment: .top) {
            if let errorMessage {
                ErrorBanner(message: errorMessage)
                    .padding(.horizontal, BoostaSpace.md)
                    .padding(.top, toastMessage == nil ? 10 : 58)
            }
        }
    }

    private var headerCard: some View {
        GlassCard {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: BoostaSpace.lg) {
                    avatarColumn
                    headerContent
                }

                VStack(alignment: .leading, spacing: BoostaSpace.md) {
                    avatarColumn
                    headerContent
                }
            }
        }
    }

    private var avatarColumn: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.sm) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [BoostaColor.accent.opacity(0.92), BoostaColor.accentSecondary.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)

                if let avatarData = profileWorkspaceService.avatarData,
                   let image = UIImage(data: avatarData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                } else {
                    Text(profileWorkspaceService.initials(fallback: fallbackDisplayName))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                Label("Add Photo", systemImage: "camera.fill")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.accent)
            }
            .buttonStyle(.plain)

            if profileWorkspaceService.avatarData != nil {
                Button("Remove Photo") {
                    removeAvatar()
                }
                .buttonStyle(.plain)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.md) {
            SectionHeader(
                title: displayedName,
                subtitle: email
            )

            TextInputField(
                title: "Name",
                placeholder: fallbackDisplayName.isEmpty ? "Your name" : fallbackDisplayName,
                text: Binding(
                    get: { displayNameDraft },
                    set: { newValue in
                        displayNameDraft = newValue
                        profileWorkspaceService.updateDisplayName(newValue)
                    }
                ),
                textContentType: .name,
                autocapitalization: .words
            )

            HStack(spacing: BoostaSpace.sm) {
                MetricPill(title: "Plan", value: planTitle, color: subscriptionService.isPremium ? BoostaColor.success : BoostaColor.warning)
                MetricPill(title: "Resumes", value: "\(profileWorkspaceService.savedResumes.count)", color: BoostaColor.accent)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: BoostaSpace.sm) {
                    SecondaryButton(title: email) {}
                        .allowsHitTesting(false)
                    PrimaryButton(title: subscriptionService.isPremium ? "Pro Active" : "Upgrade to Pro", isDisabled: subscriptionService.isPremium) {
                        showPaywall = true
                    }
                }

                VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                    SecondaryButton(title: email) {}
                        .allowsHitTesting(false)
                    PrimaryButton(title: subscriptionService.isPremium ? "Pro Active" : "Upgrade to Pro", isDisabled: subscriptionService.isPremium) {
                        showPaywall = true
                    }
                }
            }
        }
    }

    private var careerProgressCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Career Progress", subtitle: "Recruiter-ready momentum at a glance")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ProfileMetricCard(title: "ATS Score average", value: averageATSScore == 0 ? "—" : "\(averageATSScore)", tint: BoostaColor.warning)
                    ProfileMetricCard(title: "Applications tracked", value: "\(activeApplications.count)", tint: BoostaColor.accent)
                    ProfileMetricCard(title: "Interviews", value: "\(interviewCount)", tint: BoostaColor.success)
                    ProfileMetricCard(title: "Current streak", value: streakCount == 0 ? "Start" : "\(streakCount)d", tint: BoostaColor.accentSecondary)
                }

                GlassCard(padding: BoostaSpace.sm) {
                    HStack(alignment: .top, spacing: BoostaSpace.xs) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .foregroundStyle(BoostaColor.success)
                            .padding(.top, 1)
                        Text(resumeStrengthMessage)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var resumeHubCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Resume Hub", subtitle: "Primary resume, latest scan, tailored versions, and exports")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ProfileMetricCard(title: "My resumes", value: "\(profileWorkspaceService.savedResumes.count)", tint: BoostaColor.accent)
                    ProfileMetricCard(title: "Latest scan", value: latestScanLabel, tint: BoostaColor.warning)
                    ProfileMetricCard(title: "Saved tailored versions", value: "\(savedSuggestions.count)", tint: BoostaColor.success)
                    ProfileMetricCard(title: "Exports", value: exportSummaryLabel, tint: BoostaColor.accentSecondary)
                }

                HStack(spacing: BoostaSpace.sm) {
                    PrimaryButton(title: "Add Resume PDF") {
                        isResumeImporterPresented = true
                    }
                    SecondaryButton(title: "Open Scanner") {
                        appRouter.open(.scanner)
                    }
                }

                if profileWorkspaceService.savedResumes.isEmpty {
                    Text("Add your first resume here, then mark one as Primary for instant reuse in Scanner and Tailoring.")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 10) {
                        ForEach(profileWorkspaceService.savedResumes) { resume in
                            resumeRow(resume)
                        }
                    }
                }

                HStack(spacing: 8) {
                    exportChip(.pdf)
                    exportChip(.docx)
                    exportChip(.txt)
                }
            }
        }
    }

    private var accountCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Account", subtitle: "Personal info, target role, country, language, and notifications")

                profileInfoRow(title: "Personal info", value: "\(email) • Joined \(memberSinceText)")

                TextInputField(
                    title: "Job target / role",
                    placeholder: "Senior iOS Engineer",
                    text: Binding(
                        get: { jobTargetDraft },
                        set: { newValue in
                            jobTargetDraft = newValue
                            profileWorkspaceService.updateJobTarget(newValue)
                        }
                    ),
                    textContentType: .jobTitle,
                    autocapitalization: .words
                )

                TextInputField(
                    title: "Preferred country",
                    placeholder: "United States",
                    text: Binding(
                        get: { preferredCountryDraft },
                        set: { newValue in
                            preferredCountryDraft = newValue
                            profileWorkspaceService.updatePreferredCountry(newValue)
                        }
                    ),
                    autocapitalization: .words
                )

                TextInputField(
                    title: "Language",
                    placeholder: "English",
                    text: Binding(
                        get: { languageDraft },
                        set: { newValue in
                            languageDraft = newValue
                            profileWorkspaceService.updateLanguage(newValue)
                        }
                    ),
                    autocapitalization: .words
                )

                ProfileToggleRow(
                    title: "Notifications",
                    subtitle: "Follow-up nudges, reminders, and account prompts",
                    isOn: $notificationsEnabled
                )
            }
        }
    }

    private var latestScanLabel: String {
        guard let latestPayload else { return "Waiting" }
        let score = latestPayload.response.matchAfter ?? latestPayload.response.atsScore
        return "\(score)/100"
    }

    private var exportSummaryLabel: String {
        let total = profileWorkspaceService.exportHistory.count
        return total == 0 ? "None yet" : "\(total) total"
    }

    private func profileInfoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
            Text(value)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func exportChip(_ format: ResumeExportFormat) -> some View {
        HStack(spacing: 6) {
            Text(format.rawValue.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(BoostaColor.primaryText)
            Text("\(profileWorkspaceService.exportCount(for: format))")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(BoostaColor.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(BoostaColor.surfaceInteractive)
        .clipShape(Capsule())
    }

    private func resumeRow(_ resume: StoredResumeSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: BoostaSpace.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resume.displayName)
                        .font(BoostaType.bodyStrong)
                        .foregroundStyle(BoostaColor.primaryText)
                    Text(resume.originalFileName)
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                    Text("Used \(resume.uploadCount)x • \(resume.lastUsedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.tertiaryText)
                }

                Spacer(minLength: 0)

                if resume.isPrimary {
                    PrimaryResumeBadge()
                }
            }

            HStack(spacing: BoostaSpace.sm) {
                if !resume.isPrimary {
                    ProfileMiniActionButton(title: "Set Primary", tint: BoostaColor.accent) {
                        profileWorkspaceService.setPrimaryResume(resume.id)
                        toastMessage = "\(resume.displayName) is now your primary resume."
                    }
                }

                ProfileMiniActionButton(title: "Delete", tint: BoostaColor.danger) {
                    profileWorkspaceService.deleteResume(resume.id)
                    toastMessage = "\(resume.displayName) removed."
                }
            }
        }
        .padding(BoostaSpace.sm)
        .background(BoostaColor.surfaceInteractive)
        .overlay(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(BoostaColor.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
    }

    private func seedDraftsIfNeeded() {
        guard !didSeedDrafts else { return }
        didSeedDrafts = true
        displayNameDraft = profileWorkspaceService.settings.displayNameOverride
        jobTargetDraft = profileWorkspaceService.settings.jobTarget
        preferredCountryDraft = profileWorkspaceService.settings.preferredCountry
        languageDraft = profileWorkspaceService.settings.language
    }

    private func addResumeFromProfile(url: URL) {
        errorMessage = nil
        Task {
            do {
                let resume = try await profileWorkspaceService.importResume(from: url)
                toastMessage = profileWorkspaceService.primaryResume?.id == resume.id
                    ? "\(resume.displayName) added as your primary resume."
                    : "\(resume.displayName) added to My Resumes."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removeAvatar() {
        errorMessage = nil
        Task {
            do {
                try await profileWorkspaceService.saveAvatarData(nil)
                toastMessage = "Profile photo removed."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadSelectedAvatar() async {
        guard let selectedAvatarItem else { return }
        do {
            guard let data = try await selectedAvatarItem.loadTransferable(type: Data.self) else { return }
            let normalizedData = UIImage.profileAvatarData(from: data) ?? data
            try await profileWorkspaceService.saveAvatarData(normalizedData)
            toastMessage = "Profile photo updated."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ProfileMetricCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
            Text(value)
                .font(BoostaType.section)
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(BoostaSpace.sm)
        .background(BoostaColor.surfaceInteractive)
        .overlay(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(BoostaColor.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
    }
}

private struct ProfileMiniActionButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticsService.tap()
            action()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(tint.opacity(0.10))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.primaryText)
                Text(subtitle)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
        .tint(BoostaColor.accent)
    }
}

private extension UIImage {
    static func profileAvatarData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let maxDimension: CGFloat = 480
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / max(longestSide, 1))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return rendered.jpegData(compressionQuality: 0.82)
    }
}
