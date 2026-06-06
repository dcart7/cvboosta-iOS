import SwiftUI
import SwiftData

/// iPad-only Tracker workspace.
/// The iPhone Tracker experience remains in `ApplicationTrackerView` untouched.
struct ApplicationTrackerWorkspaceView_iPad: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var applications: [ApplicationRecord]

    @State private var selectedApplicationID: UUID?
    @State private var showAddSheet = false
    @State private var editingContext: ApplicationEditingContext?

    private let widgetSyncService = WidgetSyncService.shared

    private var selectedApplication: ApplicationRecord? {
        guard let id = selectedApplicationID else { return applications.first }
        return applications.first(where: { $0.id == id }) ?? applications.first
    }

    private var countsByStatus: [(title: String, value: Int, color: Color)] {
        [
            ("Saved", applications.filter { $0.status == .saved }.count, BoostaColor.secondaryText),
            ("Applied", applications.filter { $0.status == .applied }.count, BoostaColor.accent),
            ("Interview", applications.filter { $0.status == .interview }.count, BoostaColor.success),
            ("Offer", applications.filter { $0.status == .offer }.count, BoostaColor.warning),
        ]
    }

    private var priorityCounts: [(title: String, value: Int, color: Color)] {
        [
            ("Urgent", applications.filter { priority(for: $0) == .urgent }.count, BoostaColor.danger),
            ("Follow up", applications.filter { priority(for: $0) == .followUp }.count, BoostaColor.warning),
            ("Interview soon", applications.filter { priority(for: $0) == .interviewSoon }.count, BoostaColor.accentSecondary),
        ]
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

                GeometryReader { proxy in
                    let layout = TrackerWorkspaceLayout(width: proxy.size.width)

                    if applications.isEmpty {
                        emptyState
                            .padding(.horizontal, BoostaSpace.xl)
                            .frame(maxWidth: 900)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if layout.isWide {
                        HStack(alignment: .top, spacing: BoostaSpace.lg) {
                            leftListColumn
                                .frame(width: layout.leftColumnWidth)

                            rightDetailColumn
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .padding(.horizontal, BoostaSpace.xl)
                        .padding(.top, BoostaSpace.lg)
                        .padding(.bottom, BoostaSpace.xl)
                        .frame(maxWidth: 1500)
                        .frame(maxWidth: .infinity, alignment: .top)
                    } else {
                        ScrollView {
                            VStack(spacing: BoostaSpace.lg) {
                                summaryCard
                                listCard
                            }
                            .padding(.horizontal, BoostaSpace.md)
                            .padding(.top, BoostaSpace.lg)
                            .padding(.bottom, BoostaSpace.xxl)
                            .frame(maxWidth: 900)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Tracker")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    .hoverEffect(.lift)
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
            .onAppear {
                if selectedApplicationID == nil {
                    selectedApplicationID = applications.first?.id
                }
                widgetSyncService.mergeLocalApplications(applications)
            }
            .onChange(of: widgetSyncSignature) { _, _ in
                widgetSyncService.mergeLocalApplications(applications)
            }
        }
    }

    private var emptyState: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "No applications yet", subtitle: "Track job applications and interviews in a focused workspace.")
                WorkspaceActionButton(title: "Add Application", systemImage: "plus") {
                    showAddSheet = true
                }
            }
        }
    }

    private var leftListColumn: some View {
        ScrollView {
            VStack(spacing: BoostaSpace.lg) {
                summaryCard
                listCard
            }
            .padding(.bottom, BoostaSpace.xxl)
        }
        .scrollIndicators(.visible)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: BoostaSpace.sm) {
                PrimaryButton(title: "Add Application") {
                    showAddSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            .padding(.horizontal, BoostaSpace.md)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }

    private var summaryCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Pipeline", subtitle: "\(applications.count) total")

                HStack(spacing: BoostaSpace.sm) {
                    ForEach(Array(countsByStatus.enumerated()), id: \.offset) { _, item in
                        MetricPill(title: item.title, value: "\(item.value)", color: item.color)
                    }
                }

                HStack(spacing: BoostaSpace.sm) {
                    ForEach(Array(priorityCounts.enumerated()), id: \.offset) { _, item in
                        MetricPill(title: item.title, value: "\(item.value)", color: item.color)
                    }
                }
            }
        }
    }

    private var listCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Applications", subtitle: "Tap to focus details on the right")

                LazyVStack(spacing: BoostaSpace.sm) {
                    ForEach(applications) { app in
                        Button {
                            withAnimation(BoostaMotion.smooth) {
                                selectedApplicationID = app.id
                            }
                        } label: {
                            applicationRow(app, isSelected: app.id == (selectedApplication?.id ?? app.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func applicationRow(_ app: ApplicationRecord, isSelected: Bool) -> some View {
        let priority = priority(for: app)

        HStack(alignment: .top, spacing: BoostaSpace.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(app.company)
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.primaryText)
                Text(app.role)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                statusPill(app.status.rawValue, tint: statusColor(for: app.status))
                statusPill(priority.title, tint: priority.color)

                Text(app.appliedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
        .padding(BoostaSpace.sm)
        .background(Color.white.opacity(isSelected ? 0.72 : 0.55))
        .overlay(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(isSelected ? BoostaColor.accent.opacity(0.75) : BoostaColor.glassStroke, lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        .hoverEffect(.lift)
        .accessibilityLabel("\(app.company), \(app.role)")
    }

    private var rightDetailColumn: some View {
        ScrollView {
            VStack(spacing: BoostaSpace.md) {
                if let selectedApplication {
                    detailCard(selectedApplication)
                    nextStepCard(selectedApplication)
                    notesCard(selectedApplication)
                } else {
                    GlassCard(padding: BoostaSpace.lg) {
                        SectionHeader(title: "Select an application", subtitle: "Choose a row on the left to see details here.")
                    }
                }
            }
            .padding(.bottom, BoostaSpace.xxl)
        }
        .scrollIndicators(.visible)
    }

    private func detailCard(_ app: ApplicationRecord) -> some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: app.company, subtitle: app.role)

                HStack(spacing: BoostaSpace.sm) {
                    statusPill(app.status.rawValue, tint: statusColor(for: app.status))
                    statusPill(priority(for: app).title, tint: priority(for: app).color)

                    if let score = app.atsScore {
                        Text("ATS \(score)")
                            .font(BoostaType.caption)
                            .padding(.horizontal, BoostaSpace.xs)
                            .padding(.vertical, BoostaSpace.xxs)
                            .background(Color.white.opacity(0.65))
                            .clipShape(Capsule())
                    }
                }

                WorkspaceActionButton(title: "Edit Application", systemImage: "pencil") {
                    editingContext = ApplicationEditingContext(id: app.id, draft: makeDraft(from: app))
                }

                HStack(spacing: BoostaSpace.sm) {
                    WorkspaceActionButton(title: "Advance", systemImage: "arrow.right") {
                        updateStatus(id: app.id, to: nextStatus(after: app.status))
                    }

                    WorkspaceActionButton(title: "Mark Interview", systemImage: "calendar") {
                        updateStatus(id: app.id, to: .interview)
                    }
                }

                Divider()
                    .opacity(0.35)

                infoRow("Applied", value: app.appliedAt.formatted(date: .abbreviated, time: .omitted))

                if let interviewAt = app.interviewAt {
                    infoRow("Interview", value: interviewAt.formatted(date: .abbreviated, time: .shortened))
                }

                if let resume = app.resumeUsed, !resume.isEmpty {
                    infoRow("Resume used", value: resume)
                }

                if let link = app.jobLink, !link.isEmpty {
                    infoRow("Job link", value: link)
                }
            }
        }
    }

    private func nextStepCard(_ app: ApplicationRecord) -> some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Next step")
                Text(nextStep(for: app))
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private func notesCard(_ app: ApplicationRecord) -> some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Notes")
                Text((app.notes?.isEmpty == false) ? (app.notes ?? "") : "No notes yet.")
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
                    .textSelection(.enabled)
            }
        }
    }

    private func statusPill(_ status: String, tint: Color) -> some View {
        Text(status.capitalized)
            .font(BoostaType.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, BoostaSpace.xs)
            .padding(.vertical, BoostaSpace.xxs)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
            Spacer()
            Text(value)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private func nextStep(for app: ApplicationRecord) -> String {
        switch priority(for: app) {
        case .urgent:
            return "Act today while the opportunity is hot."
        case .followUp:
            return "Send a concise recruiter follow-up and refresh your role keywords."
        case .interviewSoon:
            return "Turn your strongest bullets into interview stories."
        case .steady:
            switch app.status {
            case .saved: return "Tailor this resume before applying."
            case .applied: return "Monitor recruiter response and prepare a follow-up."
            case .interview: return "Sharpen examples, metrics, and company-specific answers."
            case .offer: return "Review compensation and compare against your goals."
            case .rejected: return "Archive learnings and move the next role forward."
            }
        case .archived:
            return "Keep this for context, but focus daily energy on active pipeline work."
        }
    }

    private func priority(for app: ApplicationRecord) -> TrackerPriority {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if app.status == .offer { return .urgent }
        if app.status == .rejected { return .archived }
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
            showAddSheet = false
            if selectedApplicationID == nil {
                selectedApplicationID = record.id
            }
            widgetSyncService.mergeLocalApplications(applications)
        } catch {
            // Local-only tracker: ignore save failure, user can retry.
        }
    }

    private func updateApplication(id: UUID, with draft: NewApplicationDraft) {
        guard let record = applications.first(where: { $0.id == id }) else { return }

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
            editingContext = nil
        } catch {
            // Local-only tracker: ignore save failure, user can retry.
        }
    }

    private func updateStatus(id: UUID, to status: ApplicationStatus) {
        guard let record = applications.first(where: { $0.id == id }) else { return }
        record.status = status

        do {
            try modelContext.save()
            widgetSyncService.mergeLocalApplications(applications)
        } catch {
            // Local-only tracker: ignore save failure, user can retry.
        }
    }

    private func deleteApplication(id: UUID) {
        guard let record = applications.first(where: { $0.id == id }) else { return }
        modelContext.delete(record)

        do {
            try modelContext.save()
            widgetSyncService.mergeLocalApplications(applications.filter { $0.id != id })
            editingContext = nil
            if selectedApplicationID == id {
                selectedApplicationID = applications.first(where: { $0.id != id })?.id
            }
        } catch {
            // Local-only tracker: ignore save failure, user can retry.
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

private struct TrackerWorkspaceLayout {
    let isWide: Bool
    let leftColumnWidth: CGFloat

    init(width: CGFloat) {
        isWide = width >= 980
        if width >= 1200 {
            leftColumnWidth = 460
        } else {
            leftColumnWidth = 420
        }
    }
}

private struct WorkspaceActionButton: View {
    let title: String
    let systemImage: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
                .padding(.horizontal, BoostaSpace.md)
                .padding(.vertical, 10)
                .background(isDisabled ? Color.white.opacity(0.35) : Color.white.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                        .stroke(BoostaColor.glassStroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.65 : 1)
        .hoverEffect(.lift)
        .accessibilityLabel(title)
    }
}

#if DEBUG
#Preview("Tracker Workspace (iPad)") {
    ApplicationTrackerWorkspaceView_iPad()
        .environmentObject(AuthViewModel())
        .modelContainer(PreviewModelContainer.shared)
}
#endif
