import SwiftUI
import SwiftData

struct ApplicationTrackerView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var profileWorkspaceService = ProfileWorkspaceService.shared

    @Query(sort: \ApplicationFolder.createdAt, order: .forward)
    private var folders: [ApplicationFolder]

    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var applications: [ApplicationRecord]

    @State private var errorMessage: String?
    @State private var showAddSheet = false
    @State private var editingContext: ApplicationEditingContext?
    @State private var interviewReflectionTarget: ApplicationRecord?
    @State private var showFolderManager = false
    @State private var folderAssignmentTarget: ApplicationRecord?
    @State private var statusChangeTarget: ApplicationRecord?
    @State private var selectedScope: TrackerListScope = .active
    @State private var selectedFolderID: UUID?
    @State private var revealedApplicationID: UUID?

    private let widgetSyncService = WidgetSyncService.shared

    private var foldersByID: [UUID: ApplicationFolder] {
        Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
    }

    private var activeApplications: [ApplicationRecord] {
        applications.filter { !$0.status.isArchiveBucket }
    }

    private var scopedApplications: [ApplicationRecord] {
        switch selectedScope {
        case .active:
            return activeApplications
        case .archive:
            return applications.filter { $0.status.isArchiveBucket }
        case .all:
            return applications
        }
    }

    private var visibleApplications: [ApplicationRecord] {
        guard let selectedFolderID else { return scopedApplications }
        return scopedApplications.filter { $0.folderID == selectedFolderID }
    }

    private var interviewCount: Int {
        activeApplications.filter { $0.status == .interview }.count
    }

    private var offerCount: Int {
        activeApplications.filter { $0.status == .offer }.count
    }

    private var responseRate: Int {
        guard !activeApplications.isEmpty else { return 0 }
        let responses = activeApplications.filter { $0.status == .interview || $0.status == .offer }.count
        return Int((Double(responses) / Double(activeApplications.count)) * 100)
    }

    private var urgentCount: Int {
        activeApplications.filter { priority(for: $0) == .urgent }.count
    }

    private var interviewSoonCount: Int {
        activeApplications.filter { priority(for: $0) == .interviewSoon }.count
    }

    private var followUpCount: Int {
        activeApplications.filter { priority(for: $0) == .followUp }.count
    }

    private var widgetSyncSignature: [String] {
        applications.map {
            "\($0.id.uuidString)-\($0.status.rawValue)-\($0.appliedAt.timeIntervalSince1970)-\($0.interviewAt?.timeIntervalSince1970 ?? 0)-\($0.interviewReflectionSubmittedAt?.timeIntervalSince1970 ?? 0)"
        }
    }

    private var availableResumeNames: [String] {
        profileWorkspaceService.mergedResumeNames(remoteNames: authViewModel.me?.savedResumes.map(\.fileName) ?? [])
    }

    private var folderSelectionCandidates: [FolderAssignableApplicationOption] {
        activeApplications.map(FolderAssignableApplicationOption.init)
    }

    private var folderOptions: [ApplicationFolderOption] {
        folders.map(ApplicationFolderOption.init)
    }

    private var folderUsageCounts: [UUID: Int] {
        Dictionary(grouping: applications.compactMap { app -> UUID? in
            guard let folderID = app.folderID else { return nil }
            return folderID
        }, by: { $0 }).mapValues(\.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if applications.isEmpty {
                    VStack {
                        EmptyStateView(
                            title: "No applications yet",
                            message: "Turn job hunting into a clear pipeline with stages, notes, and conversion signals.",
                            actionTitle: "Add Application"
                        ) {
                            showAddSheet = true
                        }
                    }
                    .padding(BoostaSpace.md)
                } else {
                    ScrollView {
                        LazyVStack(spacing: BoostaSpace.sm) {
                            pipelineCard
                            if visibleApplications.isEmpty {
                                trackerEmptyStateCard
                            } else {
                                ForEach(visibleApplications) { app in
                                    applicationCard(app)
                                }
                            }
                        }
                        .padding(BoostaSpace.md)
                    }
                }
            }
            .navigationTitle("Tracker")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showFolderManager = true
                    } label: {
                        Image(systemName: "folder.badge.gearshape")
                    }

                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    AddApplicationView(
                        resumeNames: availableResumeNames,
                        folderOptions: folderOptions
                    ) { draft in
                        createApplication(draft)
                    }
                }
            }
            .sheet(item: $editingContext) { context in
                NavigationStack {
                    AddApplicationView(
                        resumeNames: availableResumeNames,
                        folderOptions: folderOptions,
                        initialDraft: context.draft,
                        saveTitle: "Save Changes",
                        showsDelete: true,
                        onSave: { draft in
                            updateApplication(id: context.id, with: draft)
                        },
                        onDelete: {
                            deleteApplication(id: context.id)
                        }
                    )
                }
            }
            .sheet(isPresented: $showFolderManager) {
                NavigationStack {
                    TrackerFolderManagerView(
                        folders: folderOptions,
                        applicationCountByFolder: folderUsageCounts,
                        availableApplications: folderSelectionCandidates,
                        onCreate: createFolder,
                        onUpdate: updateFolder,
                        onDelete: deleteFolder
                    )
                }
            }
            .sheet(item: $folderAssignmentTarget) { application in
                NavigationStack {
                    TrackerFolderAssignmentView(
                        applicationTitle: "\(application.company) • \(application.role)",
                        folderOptions: folderOptions,
                        selectedFolderID: application.folderID
                    ) { folderID in
                        assignFolder(folderID, to: application.id)
                    }
                }
            }
            .confirmationDialog(
                "Change Status",
                isPresented: Binding(
                    get: { statusChangeTarget != nil },
                    set: { if !$0 { statusChangeTarget = nil } }
                ),
                titleVisibility: .visible,
                presenting: statusChangeTarget
            ) { application in
                ForEach(TrackerListScope.statusOptions(for: application.status), id: \.self) { status in
                    Button(status.rawValue.capitalized) {
                        updateStatus(id: application.id, to: status)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { application in
                Text("\(application.company) • \(application.role)")
            }
            .sheet(item: $interviewReflectionTarget) { application in
                NavigationStack {
                    InterviewReflectionView(
                        company: application.company,
                        role: application.role,
                        initialRating: application.interviewReflectionRating,
                        initialOutcome: application.interviewReflectionOutcome,
                        initialNotes: application.interviewReflectionNotes
                    ) { reflection in
                        saveInterviewReflection(for: application.id, reflection: reflection)
                    }
                }
            }
            .overlay(alignment: .top) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                        .padding(.horizontal, BoostaSpace.md)
                        .padding(.top, BoostaSpace.sm)
                }
            }
            .onAppear {
                syncWidgetSnapshot()
                syncInterviewLiveActivity()
                presentPendingInterviewReflectionIfNeeded()
            }
            .onChange(of: widgetSyncSignature) { _, _ in
                syncWidgetSnapshot()
                syncInterviewLiveActivity()
                presentPendingInterviewReflectionIfNeeded()
            }
            .onChange(of: selectedScope) { _, _ in
                revealedApplicationID = nil
                guard let selectedFolderID else { return }
                if !folders.contains(where: { $0.id == selectedFolderID }) {
                    self.selectedFolderID = nil
                }
            }
            .onChange(of: selectedFolderID) { _, _ in
                revealedApplicationID = nil
            }
        }
    }

    private var pipelineCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Pipeline", subtitle: "Your job hunt operating system")

                HStack(spacing: BoostaSpace.sm) {
                    MetricPill(title: "Applied", value: "\(activeApplications.count)", color: BoostaColor.accent)
                    MetricPill(title: "Interviews", value: "\(interviewCount)", color: BoostaColor.warning)
                    MetricPill(title: "Offers", value: "\(offerCount)", color: BoostaColor.success)
                }

                HStack(spacing: BoostaSpace.sm) {
                    MetricPill(title: "Urgent", value: "\(urgentCount)", color: BoostaColor.danger)
                    MetricPill(title: "Follow up", value: "\(followUpCount)", color: BoostaColor.warning)
                    MetricPill(title: "Interview soon", value: "\(interviewSoonCount)", color: BoostaColor.accentSecondary)
                }

                Text(responseRate == 0 ? "Start tracking applications to unlock conversion insights." : "Current response rate: \(responseRate)%")
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)

                Picker("Tracker scope", selection: $selectedScope) {
                    ForEach(TrackerListScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                folderFilterStrip
            }
        }
    }

    private var folderFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BoostaSpace.xs) {
                TrackerFolderChip(
                    title: "All folders",
                    emoji: "🗂",
                    count: scopedApplications.count,
                    isSelected: selectedFolderID == nil
                ) {
                    selectedFolderID = nil
                }

                ForEach(folderOptions) { folder in
                    TrackerFolderChip(
                        title: folder.name,
                        emoji: folder.emoji,
                        count: scopedApplications.filter { $0.folderID == folder.id }.count,
                        isSelected: selectedFolderID == folder.id
                    ) {
                        selectedFolderID = folder.id
                    }
                }

                Button {
                    showFolderManager = true
                } label: {
                    Label("Manage", systemImage: "slider.horizontal.3")
                        .font(BoostaType.caption)
                        .padding(.horizontal, BoostaSpace.sm)
                        .padding(.vertical, 8)
                        .background(BoostaColor.surfaceInteractive)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
    }

    private var trackerEmptyStateCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Nothing in this view", subtitle: emptyTrackerSubtitle)

                HStack(spacing: BoostaSpace.sm) {
                    if selectedFolderID != nil {
                        SecondaryButton(title: "Clear Folder") {
                            selectedFolderID = nil
                        }
                    }

                    if selectedScope != .active {
                        SecondaryButton(title: "Back to Active") {
                            selectedScope = .active
                        }
                    }
                }
            }
        }
    }

    private func applicationCard(_ app: ApplicationRecord) -> some View {
        let priority = priority(for: app)

        return TrackerTelegramSwipeRow(
            isOpen: revealedApplicationID == app.id,
            onOpenChange: { isOpen in
                withAnimation(BoostaMotion.smooth) {
                    revealedApplicationID = isOpen ? app.id : nil
                }
            },
            actions: trackerDrawerActions(for: app)
        ) {
            NavigationLink {
                TrackedApplicationWorkspaceView(
                    application: app,
                    folderLabel: folderLabel(for: app),
                    isEmbedded: false,
                    showsNavigationTitle: true,
                    onEdit: {
                        editingContext = ApplicationEditingContext(id: app.id, draft: makeDraft(from: app))
                    },
                    onChangeStatus: {
                        statusChangeTarget = app
                    },
                    onArchiveToggle: {
                        updateStatus(id: app.id, to: app.status.isArchiveBucket ? .saved : .archived)
                    },
                    onMoveFolder: {
                        folderAssignmentTarget = app
                    },
                    onAdvance: {
                        updateStatus(id: app.id, to: nextStatus(after: app.status))
                    }
                )
            } label: {
                GlassCard {
                    VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.company)
                                    .font(BoostaType.bodyStrong)
                                Text(app.role)
                                    .font(BoostaType.body)
                                    .foregroundStyle(BoostaColor.secondaryText)
                                if let folderLabel = folderLabel(for: app) {
                                    ApplicationBadge(title: folderLabel, tint: BoostaColor.accentSecondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 8) {
                                ApplicationBadge(title: app.status.rawValue.capitalized, tint: statusColor(for: app.status))
                                ApplicationBadge(title: priority.title, tint: priority.color)
                            }
                        }

                        HStack {
                            Text("Applied: \(app.appliedAt.formatted(date: .abbreviated, time: .omitted))")
                            Spacer()
                            if let score = app.atsScore {
                                Text("ATS: \(score)")
                            }
                        }
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)

                        if let interviewAt = app.interviewAt, app.status == .interview {
                            Text("Interview: \(interviewAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.accentSecondary)
                        }

                        Text("Next step: \(nextStep(for: app))")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.primaryText)

                        if let notes = app.notes, !notes.isEmpty {
                            Text(notes)
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                                .lineLimit(2)
                        }

                        Label("Tap to open workspace", systemImage: "arrow.right.circle")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.accent)
                    }
                }
            }
            .buttonStyle(BoostaDepthButtonStyle())
            .contextMenu {
                trackerQuickActionsMenu(for: app)
            }
        }
    }

    private func trackerDrawerActions(for app: ApplicationRecord) -> [TrackerSwipeDrawerAction] {
        [
            TrackerSwipeDrawerAction(title: "Folder", systemImage: "folder.badge.plus", tint: BoostaColor.accentSecondary) {
                folderAssignmentTarget = app
            },
            TrackerSwipeDrawerAction(title: "Edit", systemImage: "pencil", tint: BoostaColor.accent) {
                editingContext = ApplicationEditingContext(id: app.id, draft: makeDraft(from: app))
            },
            TrackerSwipeDrawerAction(
                title: app.status.isArchiveBucket ? "Restore" : "Archive",
                systemImage: app.status.isArchiveBucket ? "arrow.uturn.backward" : "archivebox",
                tint: app.status.isArchiveBucket ? BoostaColor.accent : BoostaColor.secondaryText
            ) {
                updateStatus(id: app.id, to: app.status.isArchiveBucket ? .saved : .archived)
            },
            TrackerSwipeDrawerAction(title: "Delete", systemImage: "trash", tint: BoostaColor.danger, role: .destructive) {
                deleteApplication(id: app.id)
            }
        ]
    }

    @ViewBuilder
    private func trackerQuickActionsMenu(for app: ApplicationRecord) -> some View {
        Group {
            Button {
                folderAssignmentTarget = app
            } label: {
                Label("Folder", systemImage: "folder.badge.plus")
            }

            Button {
                editingContext = ApplicationEditingContext(id: app.id, draft: makeDraft(from: app))
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                updateStatus(id: app.id, to: app.status.isArchiveBucket ? .saved : .archived)
            } label: {
                Label(app.status.isArchiveBucket ? "Restore" : "Archive", systemImage: app.status.isArchiveBucket ? "arrow.uturn.backward" : "archivebox")
            }

            Button(role: .destructive) {
                deleteApplication(id: app.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func nextStep(for app: ApplicationRecord) -> String {
        switch priority(for: app) {
        case .urgent:
            return "Reply or act today to keep this opportunity alive."
        case .followUp:
            return "Send a recruiter follow-up and refresh your top-fit resume."
        case .interviewSoon:
            return "Prepare measurable examples and company-specific stories."
        case .steady:
            switch app.status {
            case .saved:
                return "Tailor this resume before you apply."
            case .applied:
                return "Track recruiter response and prep a follow-up."
            case .interview:
                return "Turn your strongest bullets into interview stories."
            case .offer:
                return "Review offer terms and compare total compensation."
            case .rejected:
                return "Archive learnings and move the next role forward."
            case .archived:
                return "Restore this role if you want to bring it back into the active pipeline."
            }
        case .archived:
            return "Keep this archived for learning, then focus on active roles."
        }
    }

    private func priority(for app: ApplicationRecord) -> TrackerPriority {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if app.status == .offer {
            return .urgent
        }
        if app.status.isArchiveBucket {
            return .archived
        }
        if app.status == .interview,
           let interviewAt = app.interviewAt,
           interviewAt <= (calendar.date(byAdding: .day, value: 3, to: today) ?? today) {
            return .interviewSoon
        }
        if app.status == .applied,
           let followUpDate = calendar.date(byAdding: .day, value: 5, to: calendar.startOfDay(for: app.appliedAt)),
           followUpDate <= today {
            return .followUp
        }
        return .steady
    }

    private func statusColor(for status: ApplicationStatus) -> Color {
        switch status {
        case .saved: return BoostaColor.secondaryText
        case .applied: return BoostaColor.accent
        case .interview: return BoostaColor.warning
        case .offer: return BoostaColor.success
        case .rejected: return BoostaColor.danger
        case .archived: return BoostaColor.secondaryText
        }
    }

    private func nextStatus(after status: ApplicationStatus) -> ApplicationStatus {
        switch status {
        case .saved: return .applied
        case .applied: return .interview
        case .interview: return .offer
        case .offer: return .offer
        case .rejected: return .archived
        case .archived: return .archived
        }
    }

    private func createApplication(_ draft: NewApplicationDraft) {
        errorMessage = nil

        let record = ApplicationRecord(
            company: draft.company,
            role: draft.role,
            status: draft.status,
            appliedAt: draft.appliedAt,
            source: "iOS",
            interviewAt: draft.interviewAt,
            notes: draft.notes,
            resumeUsed: draft.resumeUsed,
            jobLink: draft.jobLink,
            folderID: draft.folderID,
            atsScore: nil
        )
        modelContext.insert(record)

        do {
            try modelContext.save()
            syncWidgetSnapshot()
            celebrateStreak(with: record.status)
            presentPipelineLiveActivityIfNeeded(for: record)
            showAddSheet = false
            HapticsService.success()
        } catch {
            errorMessage = "Could not save application."
            HapticsService.error()
        }
    }

    private func updateApplication(id: UUID, with draft: NewApplicationDraft) {
        guard let record = applications.first(where: { $0.id == id }) else { return }
        errorMessage = nil

        record.company = draft.company
        record.role = draft.role
        record.status = draft.status
        record.appliedAt = draft.appliedAt
        record.interviewAt = draft.interviewAt
        record.notes = draft.notes
        record.resumeUsed = draft.resumeUsed
        record.jobLink = draft.jobLink
        record.folderID = draft.folderID

        do {
            try modelContext.save()
            syncWidgetSnapshot()
            if record.status != .archived {
                celebrateStreak(with: record.status)
            }
            presentPipelineLiveActivityIfNeeded(for: record)
            editingContext = nil
            HapticsService.success()
        } catch {
            errorMessage = "Could not update application."
            HapticsService.error()
        }
    }

    private func updateStatus(id: UUID, to status: ApplicationStatus) {
        guard let record = applications.first(where: { $0.id == id }) else { return }
        errorMessage = nil
        record.status = status

        do {
            try modelContext.save()
            statusChangeTarget = nil
            syncWidgetSnapshot()
            presentPipelineLiveActivityIfNeeded(for: record)
            if status.isArchiveBucket {
                HapticsService.warning()
            } else {
                HapticsService.success()
            }
        } catch {
            errorMessage = "Could not update application status."
            HapticsService.error()
        }
    }

    private func deleteApplication(id: UUID) {
        guard let record = applications.first(where: { $0.id == id }) else { return }
        errorMessage = nil
        modelContext.delete(record)

        do {
            try modelContext.save()
            syncWidgetSnapshot(applications.filter { $0.id != id })
            editingContext = nil
            HapticsService.warning()
        } catch {
            errorMessage = "Could not delete application."
            HapticsService.error()
        }
    }

    private func saveInterviewReflection(for id: UUID, reflection: InterviewReflectionDraft) {
        guard let record = applications.first(where: { $0.id == id }) else { return }
        errorMessage = nil
        record.interviewReflectionRating = reflection.rating
        record.interviewReflectionOutcome = reflection.outcome
        record.interviewReflectionNotes = reflection.notes
        record.interviewReflectionSubmittedAt = .now

        do {
            try modelContext.save()
            interviewReflectionTarget = nil
            if #available(iOS 16.1, *) {
                Task {
                    await LiveActivityManager.shared.clearPostInterviewReflection()
                }
            }
            HapticsService.success()
        } catch {
            errorMessage = "Could not save interview reflection."
            HapticsService.error()
        }
    }

    private func presentPendingInterviewReflectionIfNeeded() {
        guard interviewReflectionTarget == nil else { return }
        let now = Date()
        if let pending = applications
            .filter({ $0.status == .interview && ($0.interviewAt ?? .distantFuture) <= now && $0.interviewReflectionSubmittedAt == nil })
            .sorted(by: { ($0.interviewAt ?? .distantPast) > ($1.interviewAt ?? .distantPast) })
            .first {
            interviewReflectionTarget = pending
            if #available(iOS 16.1, *) {
                Task {
                    await LiveActivityManager.shared.showPostInterviewReflection(
                        company: pending.company,
                        role: pending.role
                    )
                }
            }
        }
    }

    private func assignFolder(_ folderID: UUID?, to applicationID: UUID) {
        guard let record = applications.first(where: { $0.id == applicationID }) else { return }
        record.folderID = folderID

        do {
            try modelContext.save()
            folderAssignmentTarget = nil
            HapticsService.selection()
        } catch {
            errorMessage = "Could not update folder."
            HapticsService.error()
        }
    }

    private func createFolder(_ draft: FolderCreationDraft) {
        let folder = ApplicationFolder(name: draft.folder.name, emoji: draft.folder.emoji)
        modelContext.insert(folder)

        for application in applications where draft.applicationIDs.contains(application.id) {
            application.folderID = folder.id
        }

        do {
            try modelContext.save()
            selectedFolderID = folder.id
            HapticsService.success()
        } catch {
            errorMessage = "Could not create folder."
            HapticsService.error()
        }
    }

    private func updateFolder(id: UUID, with draft: FolderDraft) {
        guard let folder = folders.first(where: { $0.id == id }) else { return }
        folder.name = draft.name
        folder.emoji = draft.emoji

        do {
            try modelContext.save()
            HapticsService.selection()
        } catch {
            errorMessage = "Could not update folder."
            HapticsService.error()
        }
    }

    private func deleteFolder(id: UUID) {
        guard let folder = folders.first(where: { $0.id == id }) else { return }

        for application in applications where application.folderID == id {
            application.folderID = nil
        }
        modelContext.delete(folder)

        do {
            try modelContext.save()
            if selectedFolderID == id {
                selectedFolderID = nil
            }
            HapticsService.warning()
        } catch {
            errorMessage = "Could not delete folder."
            HapticsService.error()
        }
    }

    private func syncInterviewLiveActivity() {
        guard #available(iOS 16.1, *) else { return }
        let now = Date()
        if let nextInterview = applications
            .filter({ $0.status == .interview && ($0.interviewAt ?? .distantPast) > now })
            .sorted(by: { ($0.interviewAt ?? .distantFuture) < ($1.interviewAt ?? .distantFuture) })
            .first,
           let interviewAt = nextInterview.interviewAt {
            Task {
                await LiveActivityManager.shared.showInterviewCountdown(
                    company: nextInterview.company,
                    role: nextInterview.role,
                    interviewAt: interviewAt
                )
            }
        } else {
            Task {
                await LiveActivityManager.shared.clearInterviewCountdown()
            }
        }
    }

    private func makeDraft(from app: ApplicationRecord) -> NewApplicationDraft {
        NewApplicationDraft(
            company: app.company,
            role: app.role,
            status: app.status,
            appliedAt: app.appliedAt,
            interviewAt: app.interviewAt,
            notes: app.notes,
            resumeUsed: app.resumeUsed,
            jobLink: app.jobLink,
            folderID: app.folderID
        )
    }

    private func folderLabel(for app: ApplicationRecord) -> String? {
        guard let folderID = app.folderID, let folder = foldersByID[folderID] else { return nil }
        return "\(folder.emoji) \(folder.name)"
    }

    private var emptyTrackerSubtitle: String {
        if let selectedFolderID, let folder = foldersByID[selectedFolderID] {
            return "No roles in \(folder.emoji) \(folder.name) for the current view."
        }

        switch selectedScope {
        case .active:
            return "Active roles will show up here."
        case .archive:
            return "Rejected and archived roles stay here until you restore them."
        case .all:
            return "No applications match the current filters."
        }
    }

    private func celebrateStreak(with status: ApplicationStatus) {
        guard #available(iOS 16.1, *) else { return }
        let summary = StreakEngine.build(
            now: .now,
            user: authViewModel.me?.user,
            scans: authViewModel.me?.scanHistory ?? [],
            applications: applications,
            manuallyProtectedDayStamps: SharedStreakState.protectedDayStamps()
        )
        let detail: String = switch status {
        case .saved: "Saved job. Streak protected."
        case .applied: "Application logged. Career momentum maintained."
        case .interview: "Interview prep counts. Streak protected."
        case .offer: "Offer progress protected your streak."
        case .rejected: "You kept momentum alive by tracking the result."
        case .archived: "Archive updated without breaking momentum."
        }
        Task {
            await LiveActivityManager.shared.celebrateDailyStreak(dayCount: summary.currentStreak, detail: detail)
        }
    }

    private func syncWidgetSnapshot(_ snapshotApplications: [ApplicationRecord]? = nil) {
        let source = snapshotApplications ?? applications
        widgetSyncService.mergeLocalApplications(source)
        widgetSyncService.syncStreakState(
            user: authViewModel.me?.user,
            scans: authViewModel.me?.scanHistory ?? [],
            applications: source
        )
    }

    private func presentPipelineLiveActivityIfNeeded(for record: ApplicationRecord) {
        guard #available(iOS 16.1, *) else { return }

        let fingerprint = [
            record.id.uuidString,
            record.status.rawValue,
            String(record.interviewAt?.timeIntervalSince1970 ?? 0)
        ].joined(separator: "|")

        Task {
            await LiveActivityManager.shared.showApplicationStatusUpdate(
                company: record.company,
                role: record.role,
                status: record.status,
                fingerprint: fingerprint
            )
        }
    }
}

private enum TrackerPriority: String {
    case urgent
    case followUp
    case interviewSoon
    case steady
    case archived

    var title: String {
        switch self {
        case .urgent: return "Urgent"
        case .followUp: return "Follow up"
        case .interviewSoon: return "Interview soon"
        case .steady: return "Active"
        case .archived: return "Archived"
        }
    }

    var color: Color {
        switch self {
        case .urgent: return BoostaColor.danger
        case .followUp: return BoostaColor.warning
        case .interviewSoon: return BoostaColor.accentSecondary
        case .steady: return BoostaColor.accent
        case .archived: return BoostaColor.secondaryText
        }
    }
}

struct NewApplicationDraft: Hashable {
    let company: String
    let role: String
    let status: ApplicationStatus
    let appliedAt: Date
    let interviewAt: Date?
    let notes: String?
    let resumeUsed: String?
    let jobLink: String?
    let folderID: UUID?
}

struct ApplicationEditingContext: Identifiable {
    let id: UUID
    let draft: NewApplicationDraft
}

struct AddApplicationView: View {
    @Environment(\.dismiss) private var dismiss

    let resumeNames: [String]
    let folderOptions: [ApplicationFolderOption]
    let saveTitle: String
    let showsDelete: Bool
    let onSave: (NewApplicationDraft) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var company = ""
    @State private var role = ""
    @State private var jobLink = ""
    @State private var status: ApplicationStatus = .saved
    @State private var appliedAt: Date = .now
    @State private var selectedResume: String = ""
    @State private var selectedFolderID: UUID?
    @State private var notes = ""
    @State private var hasInterviewDate = false
    @State private var interviewDate: Date = .now

    private var selectableStatuses: [ApplicationStatus] {
        if showsDelete, status.isArchiveBucket {
            return ApplicationStatus.userSelectableCases + [.archived]
        }
        return ApplicationStatus.userSelectableCases
    }

    init(
        resumeNames: [String],
        folderOptions: [ApplicationFolderOption] = [],
        initialDraft: NewApplicationDraft? = nil,
        saveTitle: String = "Save Application",
        showsDelete: Bool = false,
        onSave: @escaping (NewApplicationDraft) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.resumeNames = resumeNames
        self.folderOptions = folderOptions
        self.saveTitle = saveTitle
        self.showsDelete = showsDelete
        self.onSave = onSave
        self.onDelete = onDelete

        _company = State(initialValue: initialDraft?.company ?? "")
        _role = State(initialValue: initialDraft?.role ?? "")
        _jobLink = State(initialValue: initialDraft?.jobLink ?? "")
        _status = State(initialValue: initialDraft?.status ?? .saved)
        _appliedAt = State(initialValue: initialDraft?.appliedAt ?? .now)
        _selectedResume = State(initialValue: initialDraft?.resumeUsed ?? "")
        _selectedFolderID = State(initialValue: initialDraft?.folderID)
        _notes = State(initialValue: initialDraft?.notes ?? "")
        _hasInterviewDate = State(initialValue: initialDraft?.interviewAt != nil)
        _interviewDate = State(initialValue: initialDraft?.interviewAt ?? .now)
    }

    private var canSave: Bool {
        !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                GlassCard {
                    VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                        TextInputField(title: "Company name", placeholder: "Google", text: $company)
                        TextInputField(title: "Job title", placeholder: "Backend Engineer", text: $role)
                        TextInputField(
                            title: "Job link",
                            placeholder: "https://...",
                            text: $jobLink,
                            keyboardType: .URL,
                            autocapitalization: .never
                        )

                        Picker("Status", selection: $status) {
                            ForEach(selectableStatuses, id: \.self) { item in
                                Text(item.rawValue.capitalized).tag(item)
                            }
                        }
                        .pickerStyle(.menu)

                        DatePicker("Date applied", selection: $appliedAt, displayedComponents: .date)

                        Picker("Resume used", selection: $selectedResume) {
                            Text("Not selected").tag("")
                            ForEach(resumeNames, id: \.self) { item in
                                Text(item).tag(item)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Folder", selection: $selectedFolderID) {
                            Text("No folder").tag(Optional<UUID>.none)
                            ForEach(folderOptions) { folder in
                                Text("\(folder.emoji) \(folder.name)")
                                    .tag(Optional(folder.id))
                            }
                        }
                        .pickerStyle(.menu)

                        VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                            Text("Notes")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                            TextEditor(text: $notes)
                                .frame(minHeight: 110)
                                .padding(BoostaSpace.xs)
                                .background(BoostaColor.surfaceInteractiveStrong)
                                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
                        }

                        Toggle("Interview date", isOn: $hasInterviewDate)
                        if hasInterviewDate {
                            DatePicker("Interview", selection: $interviewDate)
                        }

                        PrimaryButton(title: saveTitle, isDisabled: !canSave) {
                            let draft = NewApplicationDraft(
                                company: company.trimmingCharacters(in: .whitespacesAndNewlines),
                                role: role.trimmingCharacters(in: .whitespacesAndNewlines),
                                status: status,
                                appliedAt: appliedAt,
                                interviewAt: hasInterviewDate ? interviewDate : nil,
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                                resumeUsed: selectedResume.isEmpty ? nil : selectedResume,
                                jobLink: jobLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : jobLink,
                                folderID: selectedFolderID
                            )
                            onSave(draft)
                        }

                        if showsDelete, let onDelete {
                            SecondaryButton(title: "Delete Application") {
                                onDelete()
                            }
                            .foregroundStyle(BoostaColor.danger)
                        }
                    }
                }
                .padding(BoostaSpace.md)
            }
        }
        .navigationTitle(showsDelete ? "Edit Application" : "Add Application")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
    }
}

private struct ApplicationBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(BoostaType.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, BoostaSpace.xs)
            .padding(.vertical, BoostaSpace.xxs)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

enum TrackerListScope: String, CaseIterable, Identifiable {
    case active
    case archive
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: return "Active"
        case .archive: return "Archive"
        case .all: return "All"
        }
    }

    static func statusOptions(for current: ApplicationStatus) -> [ApplicationStatus] {
        if current.isArchiveBucket {
            return [.saved, .applied, .interview, .offer, .rejected]
        }
        return ApplicationStatus.userSelectableCases + [.archived]
    }
}

struct ApplicationFolderOption: Identifiable, Hashable {
    let id: UUID
    let name: String
    let emoji: String

    init(folder: ApplicationFolder) {
        id = folder.id
        name = folder.name
        emoji = folder.emoji
    }
}

struct FolderDraft: Hashable {
    let name: String
    let emoji: String
}

struct FolderCreationDraft: Hashable {
    let folder: FolderDraft
    let applicationIDs: Set<UUID>
}

struct FolderAssignableApplicationOption: Identifiable, Hashable {
    let id: UUID
    let company: String
    let role: String
    let appliedAt: Date

    init(application: ApplicationRecord) {
        id = application.id
        company = application.company
        role = application.role
        appliedAt = application.appliedAt
    }

    var title: String {
        "\(company) • \(role)"
    }

    var subtitle: String {
        appliedAt.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct FolderEditorContext: Identifiable {
    let id: UUID?
    let name: String
    let emoji: String
    let selectedApplicationIDs: Set<UUID>
}

struct TrackerFolderChip: View {
    let title: String
    let emoji: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticsService.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                Text(emoji)
                Text(title)
                Text("\(count)")
                    .foregroundStyle(BoostaColor.secondaryText)
            }
            .font(BoostaType.caption)
            .padding(.horizontal, BoostaSpace.sm)
            .padding(.vertical, 8)
            .background(isSelected ? BoostaColor.surfaceInteractiveStrong : BoostaColor.surfaceInteractive)
            .overlay(
                Capsule()
                    .stroke(isSelected ? BoostaColor.accent : BoostaColor.glassStroke, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(BoostaDepthButtonStyle())
    }
}

struct TrackerSwipeDrawerAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tint: Color
    var role: ButtonRole? = nil
    let action: () -> Void
}

struct TrackerTelegramSwipeRow<Content: View>: View {
    let isOpen: Bool
    let onOpenChange: (Bool) -> Void
    let actions: [TrackerSwipeDrawerAction]
    let cornerRadius: CGFloat
    let content: () -> Content

    @GestureState private var dragTranslation: CGFloat = 0

    init(
        isOpen: Bool,
        onOpenChange: @escaping (Bool) -> Void,
        actions: [TrackerSwipeDrawerAction],
        cornerRadius: CGFloat = BoostaRadius.md,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isOpen = isOpen
        self.onOpenChange = onOpenChange
        self.actions = actions
        self.cornerRadius = cornerRadius
        self.content = content
    }

    private var drawerWidth: CGFloat {
        CGFloat(actions.count) * 78
    }

    private var contentOffset: CGFloat {
        let base = isOpen ? -drawerWidth : 0
        return max(-drawerWidth, min(0, base + dragTranslation))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    ForEach(actions) { action in
                        TrackerSwipeDrawerButton(action: action) {
                            closeDrawer()
                            Task { @MainActor in
                                action.action()
                            }
                        }
                    }
                }
                .frame(width: drawerWidth)
                .frame(maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }

            content()
                .offset(x: contentOffset)
                .overlay {
                    if isOpen {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                closeDrawer()
                            }
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .simultaneousGesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                let base = isOpen ? -drawerWidth : 0
                let projected = max(-drawerWidth, min(0, base + value.predictedEndTranslation.width))
                let shouldOpen = projected < -(drawerWidth * 0.34)

                if shouldOpen != isOpen {
                    HapticsService.selection()
                }

                withAnimation(BoostaMotion.smooth) {
                    onOpenChange(shouldOpen)
                }
            }
    }

    private func closeDrawer() {
        withAnimation(BoostaMotion.smooth) {
            onOpenChange(false)
        }
    }
}

private struct TrackerSwipeDrawerButton: View {
    let action: TrackerSwipeDrawerAction
    let onTap: () -> Void

    var body: some View {
        Button(role: action.role) {
            onTap()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(action.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 6)
            .background(action.tint)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)
            }
        }
        .buttonStyle(BoostaDepthButtonStyle(pressedScale: 0.97, pressedOpacity: 0.94, verticalOffset: 0))
        .accessibilityLabel(action.title)
    }
}

struct TrackerFolderManagerView: View {
    @Environment(\.dismiss) private var dismiss

    let folders: [ApplicationFolderOption]
    let applicationCountByFolder: [UUID: Int]
    let availableApplications: [FolderAssignableApplicationOption]
    let onCreate: (FolderCreationDraft) -> Void
    let onUpdate: (UUID, FolderDraft) -> Void
    let onDelete: (UUID) -> Void

    @State private var editorContext: FolderEditorContext?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                GlassCard {
                    VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                        SectionHeader(title: "Folders", subtitle: "Organize roles by lane, company set, or hiring focus.")

                        PrimaryButton(title: "Create Folder") {
                            editorContext = FolderEditorContext(id: nil, name: "", emoji: "🗂", selectedApplicationIDs: [])
                        }

                        if folders.isEmpty {
                            Text("No folders yet.")
                                .font(BoostaType.body)
                                .foregroundStyle(BoostaColor.secondaryText)
                        } else {
                            ForEach(folders) { folder in
                                HStack(spacing: BoostaSpace.sm) {
                                    Text(folder.emoji)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(folder.name)
                                            .font(BoostaType.bodyStrong)
                                        Text("\(applicationCountByFolder[folder.id] ?? 0) role(s)")
                                            .font(BoostaType.caption)
                                            .foregroundStyle(BoostaColor.secondaryText)
                                    }

                                    Spacer()

                                    Button("Edit") {
                                        editorContext = FolderEditorContext(id: folder.id, name: folder.name, emoji: folder.emoji, selectedApplicationIDs: [])
                                    }
                                    .buttonStyle(BoostaDepthButtonStyle())
                                    .foregroundStyle(BoostaColor.accent)

                                    Button("Delete", role: .destructive) {
                                        onDelete(folder.id)
                                    }
                                    .buttonStyle(BoostaDepthButtonStyle())
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(BoostaSpace.md)
            }
        }
        .navigationTitle("Manage Folders")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
        .sheet(item: $editorContext) { context in
            NavigationStack {
                TrackerFolderEditorView(
                    initialName: context.name,
                    initialEmoji: context.emoji,
                    initialSelectedApplicationIDs: context.selectedApplicationIDs,
                    availableApplications: availableApplications,
                    saveTitle: context.id == nil ? "Create Folder" : "Save Folder",
                    showsApplicationSelection: context.id == nil
                ) { draft, selectedApplicationIDs in
                    if let id = context.id {
                        onUpdate(id, draft)
                    } else {
                        onCreate(FolderCreationDraft(folder: draft, applicationIDs: selectedApplicationIDs))
                    }
                }
            }
        }
    }
}

private struct TrackerFolderEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let initialName: String
    let initialEmoji: String
    let initialSelectedApplicationIDs: Set<UUID>
    let availableApplications: [FolderAssignableApplicationOption]
    let saveTitle: String
    let showsApplicationSelection: Bool
    let onSave: (FolderDraft, Set<UUID>) -> Void

    @State private var name: String
    @State private var emoji: String
    @State private var selectedApplicationIDs: Set<UUID>

    init(
        initialName: String,
        initialEmoji: String,
        initialSelectedApplicationIDs: Set<UUID> = [],
        availableApplications: [FolderAssignableApplicationOption] = [],
        saveTitle: String,
        showsApplicationSelection: Bool = false,
        onSave: @escaping (FolderDraft, Set<UUID>) -> Void
    ) {
        self.initialName = initialName
        self.initialEmoji = initialEmoji
        self.initialSelectedApplicationIDs = initialSelectedApplicationIDs
        self.availableApplications = availableApplications
        self.saveTitle = saveTitle
        self.showsApplicationSelection = showsApplicationSelection
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _emoji = State(initialValue: initialEmoji)
        _selectedApplicationIDs = State(initialValue: initialSelectedApplicationIDs)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                GlassCard {
                    VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                        TextInputField(title: "Emoji", placeholder: "🗂", text: $emoji)
                        TextInputField(title: "Folder name", placeholder: "Priority Roles", text: $name)

                        if showsApplicationSelection {
                            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                                SectionHeader(
                                    title: "Add Vacancies Now",
                                    subtitle: availableApplications.isEmpty
                                        ? "No active vacancies available yet."
                                        : "Pick which roles should go into this folder immediately."
                                )

                                if availableApplications.isEmpty {
                                    Text("Create the folder now and add roles later from the swipe drawer.")
                                        .font(BoostaType.caption)
                                        .foregroundStyle(BoostaColor.secondaryText)
                                } else {
                                    ForEach(availableApplications) { application in
                                        Button {
                                            toggleApplicationSelection(application.id)
                                        } label: {
                                            HStack(spacing: BoostaSpace.sm) {
                                                Image(systemName: selectedApplicationIDs.contains(application.id) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(selectedApplicationIDs.contains(application.id) ? BoostaColor.accent : BoostaColor.secondaryText)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(application.title)
                                                        .font(BoostaType.bodyStrong)
                                                        .foregroundStyle(BoostaColor.primaryText)
                                                    Text(application.subtitle)
                                                        .font(BoostaType.caption)
                                                        .foregroundStyle(BoostaColor.secondaryText)
                                                }
                                                Spacer(minLength: 0)
                                            }
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(BoostaDepthButtonStyle())
                                    }
                                }
                            }
                        }

                        PrimaryButton(title: saveTitle, isDisabled: !canSave) {
                            onSave(
                                FolderDraft(
                                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                    emoji: emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "🗂" : emoji.trimmingCharacters(in: .whitespacesAndNewlines)
                                ),
                                selectedApplicationIDs
                            )
                            dismiss()
                        }
                    }
                }
                .padding(BoostaSpace.md)
            }
        }
        .navigationTitle("Folder")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func toggleApplicationSelection(_ id: UUID) {
        if selectedApplicationIDs.contains(id) {
            selectedApplicationIDs.remove(id)
        } else {
            selectedApplicationIDs.insert(id)
        }
        HapticsService.selection()
    }
}

struct TrackerFolderAssignmentView: View {
    @Environment(\.dismiss) private var dismiss

    let applicationTitle: String
    let folderOptions: [ApplicationFolderOption]
    let selectedFolderID: UUID?
    let onAssign: (UUID?) -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                GlassCard {
                    VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                        SectionHeader(title: "Move to Folder", subtitle: applicationTitle)

                        Button {
                            onAssign(nil)
                            dismiss()
                        } label: {
                            folderRow(title: "No folder", emoji: "🗂", isSelected: selectedFolderID == nil)
                        }
                        .buttonStyle(BoostaDepthButtonStyle())

                        ForEach(folderOptions) { folder in
                            Button {
                                onAssign(folder.id)
                                dismiss()
                            } label: {
                                folderRow(title: folder.name, emoji: folder.emoji, isSelected: selectedFolderID == folder.id)
                            }
                            .buttonStyle(BoostaDepthButtonStyle())
                        }
                    }
                }
                .padding(BoostaSpace.md)
            }
        }
        .navigationTitle("Folder")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func folderRow(title: String, emoji: String, isSelected: Bool) -> some View {
        HStack(spacing: BoostaSpace.sm) {
            Text(emoji)
            Text(title)
                .font(BoostaType.bodyStrong)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(BoostaColor.accent)
            }
        }
        .padding(.vertical, 6)
    }
}

struct InterviewReflectionDraft {
    let rating: Int
    let outcome: String
    let notes: String?
}

struct InterviewReflectionView: View {
    @Environment(\.dismiss) private var dismiss

    let company: String
    let role: String
    let initialRating: Int?
    let initialOutcome: String?
    let initialNotes: String?
    let onSave: (InterviewReflectionDraft) -> Void

    @State private var rating: Int
    @State private var outcome: String
    @State private var notes: String

    init(
        company: String,
        role: String,
        initialRating: Int?,
        initialOutcome: String?,
        initialNotes: String?,
        onSave: @escaping (InterviewReflectionDraft) -> Void
    ) {
        self.company = company
        self.role = role
        self.initialRating = initialRating
        self.initialOutcome = initialOutcome
        self.initialNotes = initialNotes
        self.onSave = onSave
        _rating = State(initialValue: initialRating ?? 3)
        _outcome = State(initialValue: initialOutcome ?? "Went well")
        _notes = State(initialValue: initialNotes ?? "")
    }

    private let outcomes = ["Went well", "Mixed", "Needs improvement", "Waiting for feedback"]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                GlassCard {
                    VStack(alignment: .leading, spacing: BoostaSpace.md) {
                        SectionHeader(
                            title: "How did the interview go?",
                            subtitle: "\(company) • \(role)"
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confidence")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)

                            HStack(spacing: 10) {
                                ForEach(1...5, id: \.self) { value in
                                    Button {
                                        rating = value
                                    } label: {
                                        Image(systemName: value <= rating ? "star.fill" : "star")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(value <= rating ? BoostaColor.warning : BoostaColor.secondaryText)
                                    }
                                    .buttonStyle(BoostaDepthButtonStyle(pressedScale: 0.93, pressedOpacity: 0.92, verticalOffset: 0))
                                }
                            }
                        }

                        Picker("Outcome", selection: $outcome) {
                            ForEach(outcomes, id: \.self) { item in
                                Text(item).tag(item)
                            }
                        }
                        .pickerStyle(.menu)

                        VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                            Text("Notes")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                            TextEditor(text: $notes)
                                .frame(minHeight: 140)
                                .padding(BoostaSpace.xs)
                                .background(BoostaColor.surfaceInteractiveStrong)
                                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
                        }

                        PrimaryButton(title: "Save Reflection") {
                            onSave(
                                InterviewReflectionDraft(
                                    rating: rating,
                                    outcome: outcome,
                                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
                                )
                            )
                            dismiss()
                        }
                    }
                }
                .padding(BoostaSpace.md)
            }
        }
        .navigationTitle("Interview Reflection")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
    }
}
