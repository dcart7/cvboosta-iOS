import SwiftUI
import SwiftData

struct ApplicationTrackerView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var applications: [ApplicationRecord]

    @State private var errorMessage: String?
    @State private var showAddSheet = false
    @State private var editingContext: ApplicationEditingContext?

    private let widgetSyncService = WidgetSyncService.shared

    private var interviewCount: Int {
        applications.filter { $0.status == .interview }.count
    }

    private var offerCount: Int {
        applications.filter { $0.status == .offer }.count
    }

    private var responseRate: Int {
        guard !applications.isEmpty else { return 0 }
        let responses = applications.filter { $0.status == .interview || $0.status == .offer }.count
        return Int((Double(responses) / Double(applications.count)) * 100)
    }

    private var urgentCount: Int {
        applications.filter { priority(for: $0) == .urgent }.count
    }

    private var interviewSoonCount: Int {
        applications.filter { priority(for: $0) == .interviewSoon }.count
    }

    private var followUpCount: Int {
        applications.filter { priority(for: $0) == .followUp }.count
    }

    private var widgetSyncSignature: [String] {
        applications.map { "\($0.id.uuidString)-\($0.status.rawValue)-\($0.appliedAt.timeIntervalSince1970)" }
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
                        VStack(spacing: BoostaSpace.sm) {
                            pipelineCard
                            ForEach(applications) { app in
                                applicationCard(app)
                            }
                        }
                        .padding(BoostaSpace.md)
                    }
                }
            }
            .navigationTitle("Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    AddApplicationView(resumeNames: authViewModel.me?.savedResumes.map(\.fileName) ?? []) { draft in
                        createApplication(draft)
                    }
                }
            }
            .sheet(item: $editingContext) { context in
                NavigationStack {
                    AddApplicationView(
                        resumeNames: authViewModel.me?.savedResumes.map(\.fileName) ?? [],
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
            .overlay(alignment: .top) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                        .padding(.horizontal, BoostaSpace.md)
                        .padding(.top, BoostaSpace.sm)
                }
            }
            .onAppear {
                widgetSyncService.mergeLocalApplications(applications)
            }
            .onChange(of: widgetSyncSignature) { _, _ in
                widgetSyncService.mergeLocalApplications(applications)
            }
        }
    }

    private var pipelineCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Pipeline", subtitle: "Your job hunt operating system")

                HStack(spacing: BoostaSpace.sm) {
                    MetricPill(title: "Applied", value: "\(applications.count)", color: BoostaColor.accent)
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
            }
        }
    }

    private func applicationCard(_ app: ApplicationRecord) -> some View {
        let priority = priority(for: app)

        return GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.company)
                            .font(BoostaType.bodyStrong)
                        Text(app.role)
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
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
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingContext = ApplicationEditingContext(id: app.id, draft: makeDraft(from: app))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Interview") {
                updateStatus(id: app.id, to: .interview)
            }
            .tint(BoostaColor.warning)

            Button("Done") {
                updateStatus(id: app.id, to: nextStatus(after: app.status))
            }
            .tint(BoostaColor.success)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteApplication(id: app.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                editingContext = ApplicationEditingContext(id: app.id, draft: makeDraft(from: app))
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(BoostaColor.accent)
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
        if app.status == .rejected {
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
        }
    }

    private func nextStatus(after status: ApplicationStatus) -> ApplicationStatus {
        switch status {
        case .saved: return .applied
        case .applied: return .interview
        case .interview: return .offer
        case .offer: return .offer
        case .rejected: return .rejected
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
            atsScore: nil
        )
        modelContext.insert(record)

        do {
            try modelContext.save()
            widgetSyncService.mergeLocalApplications(applications)
            celebrateStreak(with: record.status)
            showAddSheet = false
        } catch {
            errorMessage = "Could not save application."
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

        do {
            try modelContext.save()
            widgetSyncService.mergeLocalApplications(applications)
            celebrateStreak(with: record.status)
            editingContext = nil
        } catch {
            errorMessage = "Could not update application."
        }
    }

    private func updateStatus(id: UUID, to status: ApplicationStatus) {
        guard let record = applications.first(where: { $0.id == id }) else { return }
        errorMessage = nil
        record.status = status

        do {
            try modelContext.save()
            widgetSyncService.mergeLocalApplications(applications)
        } catch {
            errorMessage = "Could not update application status."
        }
    }

    private func deleteApplication(id: UUID) {
        guard let record = applications.first(where: { $0.id == id }) else { return }
        errorMessage = nil
        modelContext.delete(record)

        do {
            try modelContext.save()
            widgetSyncService.mergeLocalApplications(applications.filter { $0.id != id })
            editingContext = nil
        } catch {
            errorMessage = "Could not delete application."
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
            jobLink: app.jobLink
        )
    }

    private func celebrateStreak(with status: ApplicationStatus) {
        guard #available(iOS 16.1, *) else { return }
        let summary = StreakEngine.build(
            now: .now,
            user: authViewModel.me?.user,
            scans: authViewModel.me?.scanHistory ?? [],
            applications: applications,
            manuallyProtectedDayStamps: []
        )
        let detail: String = switch status {
        case .saved: "Saved job. Streak protected."
        case .applied: "Application logged. Career momentum maintained."
        case .interview: "Interview prep counts. Streak protected."
        case .offer: "Offer progress protected your streak."
        case .rejected: "You kept momentum alive by tracking the result."
        }
        Task {
            await LiveActivityManager.shared.celebrateDailyStreak(dayCount: summary.currentStreak, detail: detail)
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
}

struct ApplicationEditingContext: Identifiable {
    let id: UUID
    let draft: NewApplicationDraft
}

struct AddApplicationView: View {
    @Environment(\.dismiss) private var dismiss

    let resumeNames: [String]
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
    @State private var notes = ""
    @State private var hasInterviewDate = false
    @State private var interviewDate: Date = .now

    init(
        resumeNames: [String],
        initialDraft: NewApplicationDraft? = nil,
        saveTitle: String = "Save Application",
        showsDelete: Bool = false,
        onSave: @escaping (NewApplicationDraft) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.resumeNames = resumeNames
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
                            ForEach(ApplicationStatus.allCases, id: \.self) { item in
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

                        VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                            Text("Notes")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                            TextEditor(text: $notes)
                                .frame(minHeight: 110)
                                .padding(BoostaSpace.xs)
                                .background(Color.white.opacity(0.65))
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
                                jobLink: jobLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : jobLink
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
