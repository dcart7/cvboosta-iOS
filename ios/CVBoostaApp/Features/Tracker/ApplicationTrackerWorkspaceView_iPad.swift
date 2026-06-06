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
                Text(app.status.rawValue.capitalized)
                    .font(BoostaType.caption)
                    .padding(.horizontal, BoostaSpace.xs)
                    .padding(.vertical, BoostaSpace.xxs)
                    .background(Color.white.opacity(0.65))
                    .clipShape(Capsule())

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
                    statusPill(app.status.rawValue)

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
                Text(nextStep(for: app.status))
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

    private func statusPill(_ status: String) -> some View {
        Text(status.capitalized)
            .font(BoostaType.caption)
            .padding(.horizontal, BoostaSpace.xs)
            .padding(.vertical, BoostaSpace.xxs)
            .background(Color.white.opacity(0.65))
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

    private func nextStep(for status: ApplicationStatus) -> String {
        switch status {
        case .saved:
            return "Submit application"
        case .applied:
            return "Follow up in 5 days"
        case .interview:
            return "Prepare interview examples"
        case .offer:
            return "Review offer terms"
        case .rejected:
            return "Retrospective and apply next"
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
