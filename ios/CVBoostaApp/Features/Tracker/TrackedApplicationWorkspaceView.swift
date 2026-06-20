import PDFKit
import SwiftUI
import UIKit

struct TrackedApplicationWorkspaceView: View {
    @EnvironmentObject private var appRouter: AppRouter
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    let application: ApplicationRecord
    let folderLabel: String?
    let isEmbedded: Bool
    let showsNavigationTitle: Bool
    let onEdit: () -> Void
    let onChangeStatus: () -> Void
    let onArchiveToggle: () -> Void
    let onMoveFolder: () -> Void
    let onAdvance: () -> Void

    @State private var selectedStage: TrackerWorkspaceStage = .saved
    @State private var coverLetter: GeneratedCoverLetter?
    @State private var interviewPrep: GeneratedInterviewPrep?
    @State private var previewDocument: GeneratedPDFPreviewDocument?
    @State private var paywallContext: PaywallPresentationContext?
    @State private var feedbackMessage: String?

    init(
        application: ApplicationRecord,
        folderLabel: String?,
        isEmbedded: Bool = false,
        showsNavigationTitle: Bool = true,
        onEdit: @escaping () -> Void,
        onChangeStatus: @escaping () -> Void,
        onArchiveToggle: @escaping () -> Void,
        onMoveFolder: @escaping () -> Void,
        onAdvance: @escaping () -> Void
    ) {
        self.application = application
        self.folderLabel = folderLabel
        self.isEmbedded = isEmbedded
        self.showsNavigationTitle = showsNavigationTitle
        self.onEdit = onEdit
        self.onChangeStatus = onChangeStatus
        self.onArchiveToggle = onArchiveToggle
        self.onMoveFolder = onMoveFolder
        self.onAdvance = onAdvance
    }

    var body: some View {
        Group {
            if isEmbedded {
                workspaceSections
            } else {
                ScrollView {
                    workspaceSections
                        .padding(.horizontal, BoostaSpace.md)
                        .padding(.top, BoostaSpace.md)
                        .padding(.bottom, BoostaSpace.xxl)
                }
                .safeAreaInset(edge: .bottom) {
                    quickActionsBar
                        .padding(.horizontal, BoostaSpace.md)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                        .background(.ultraThinMaterial)
                }
            }
        }
        .navigationTitle(showsNavigationTitle ? application.role : "")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewDocument) { document in
            GeneratedPDFPreviewSheet(document: document)
        }
        .sheet(item: $paywallContext) { context in
            NavigationStack {
                PaywallView(context: context)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task(id: application.id) {
            hydrateWorkspaceState()
        }
        .onChange(of: application.status) { _, newStatus in
            withAnimation(BoostaMotion.smooth) {
                selectedStage = stageForCurrentProgress(status: newStatus)
            }
        }
    }

    private var workspaceSections: some View {
        VStack(spacing: BoostaSpace.lg) {
            headerCard
            progressCard
            analyticsCard
            insightsCard
            coverLetterCard
            interviewPrepCard
            documentsCard
            timelineCard
            notesCard

            if isEmbedded {
                quickActionsBar
            }

            if let feedbackMessage {
                GlassCard(padding: BoostaSpace.sm) {
                    Text(feedbackMessage)
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var headerCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: BoostaSpace.md) {
                        headerIdentity
                        Spacer(minLength: 0)
                        headerActions
                    }

                    VStack(alignment: .leading, spacing: BoostaSpace.md) {
                        headerIdentity
                        headerActions
                    }
                }

                HStack(spacing: BoostaSpace.sm) {
                    WorkspaceInfoChip(title: "Applied", value: application.appliedAt.formatted(date: .abbreviated, time: .omitted))
                    WorkspaceInfoChip(title: "Last activity", value: lastActivityDate.formatted(date: .abbreviated, time: .shortened))
                }

                if let folderLabel {
                    WorkspaceInfoChip(title: "Folder", value: folderLabel)
                }
            }
        }
    }

    private var headerIdentity: some View {
        HStack(alignment: .top, spacing: BoostaSpace.md) {
            ZStack {
                Circle()
                    .fill(BoostaColor.auroraGradient)
                    .frame(width: 64, height: 64)
                Text(companyInitials)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                Text(application.role)
                    .font(BoostaType.title)
                    .foregroundStyle(BoostaColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(application.company)
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)

                HStack(spacing: BoostaSpace.xs) {
                    WorkspaceStatusPill(title: application.status.rawValue.capitalized, tint: statusColor(for: application.status))
                    WorkspaceStatusPill(title: "ATS \(currentATSScore)", tint: BoostaColor.accent)
                    WorkspaceStatusPill(title: journeyStage.title, tint: journeyStage.tint)
                }

                Text("Career workspace for this role: progress, ATS momentum, AI assets, and next actions in one place.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private var headerActions: some View {
        HStack(spacing: BoostaSpace.xs) {
            WorkspaceHeaderButton(title: "Edit", systemImage: "pencil", tint: BoostaColor.accent, action: onEdit)

            WorkspaceHeaderButton(
                title: coverLetter == nil ? "Generate" : "Export",
                systemImage: "square.and.arrow.up",
                tint: BoostaColor.success
            ) {
                if coverLetter == nil {
                    generateCoverLetter(exportAfterGeneration: true)
                } else {
                    exportCoverLetterPDF()
                }
            }

            Menu {
                if application.status != .offer && !application.status.isArchiveBucket {
                    Button("Advance Stage", systemImage: "arrow.right.circle") {
                        onAdvance()
                    }
                }

                Button("Change Status", systemImage: "arrow.triangle.2.circlepath") {
                    onChangeStatus()
                }

                Button("Move Folder", systemImage: "folder.badge.plus") {
                    onMoveFolder()
                }

                Button("Open Tailoring", systemImage: "wand.and.stars") {
                    openTailoringWorkspace(message: "Tailoring workspace opened for this role.")
                }

                Button(
                    application.status.isArchiveBucket ? "Restore to Active" : "Move to Archive",
                    systemImage: application.status.isArchiveBucket ? "arrow.uturn.backward.circle" : "archivebox"
                ) {
                    onArchiveToggle()
                }
            } label: {
                WorkspaceHeaderButtonLabel(title: "More", systemImage: "ellipsis")
            }
        }
    }

    private var progressCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(
                    title: "Progression",
                    subtitle: "Saved to offer, with context and momentum instead of a generic form."
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BoostaSpace.xs) {
                        ForEach(Array(TrackerWorkspaceStage.allCases.enumerated()), id: \.element.id) { index, stage in
                            HStack(spacing: BoostaSpace.xs) {
                                ProgressStageNode(
                                    stage: stage,
                                    isSelected: selectedStage == stage,
                                    isCompleted: stage.order <= journeyStage.order
                                ) {
                                    withAnimation(BoostaMotion.smooth) {
                                        selectedStage = stage
                                    }
                                }

                                if index < TrackerWorkspaceStage.allCases.count - 1 {
                                    Capsule()
                                        .fill(stage.order < journeyStage.order ? stage.tint.opacity(0.35) : BoostaColor.glassStroke)
                                        .frame(width: 28, height: 2)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                    Text(selectedStage.title)
                        .font(BoostaType.bodyStrong)
                        .foregroundStyle(BoostaColor.primaryText)

                    Text(selectedStageNote(for: selectedStage))
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)

                    if let timestamp = selectedStageDate(for: selectedStage) {
                        Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(BoostaType.caption)
                            .foregroundStyle(selectedStage.tint)
                    }
                }
            }
        }
    }

    private var analyticsCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(
                    title: "ATS Analytics",
                    subtitle: "A calm dashboard view of fit, readability, and improvement signal."
                )

                TrackerTrendChart(points: analyticsTrend, tint: BoostaColor.accent)
                    .frame(height: 180)

                Text("+\(scoreImprovement) score improvement")
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.success)

                Text("Top improvement: \(topImprovementLabel)")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 120), spacing: BoostaSpace.sm),
                        GridItem(.flexible(minimum: 120), spacing: BoostaSpace.sm)
                    ],
                    spacing: BoostaSpace.sm
                ) {
                    MetricPill(title: "ATS match", value: "\(currentATSScore)", color: BoostaColor.accent)
                    MetricPill(title: "Keyword match", value: "\(keywordMatchScore)", color: BoostaColor.success)
                    MetricPill(title: "Readability", value: "\(readabilityScore)", color: BoostaColor.accentSecondary)
                    MetricPill(title: "Technical impact", value: "\(technicalImpactScore)", color: BoostaColor.warning)
                }
            }
        }
    }

    private var insightsCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(
                    title: "AI Insights",
                    subtitle: "Short, useful recommendations instead of giant paragraphs."
                )

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 190), spacing: BoostaSpace.sm)],
                    spacing: BoostaSpace.sm
                ) {
                    ForEach(insightItems) { insight in
                        WorkspaceInsightCard(insight: insight)
                    }
                }
            }
        }
    }

    private var coverLetterCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                HStack(alignment: .top, spacing: BoostaSpace.sm) {
                    SectionHeader(
                        title: "Cover Letter Generator",
                        subtitle: "Copy the text instantly or export it as a polished PDF."
                    )

                    Spacer(minLength: 0)

                    WorkspaceStatusPill(title: coverLetterLimitStatus.summary, tint: coverLetterLimitStatus.canUse ? BoostaColor.success : BoostaColor.warning)
                }

                if let coverLetter {
                    VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                        Text(coverLetter.title)
                            .font(BoostaType.bodyStrong)
                            .foregroundStyle(BoostaColor.primaryText)
                        Text(coverLetter.subtitle)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                        Text(coverLetter.body)
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.primaryText)
                            .textSelection(.enabled)
                    }
                } else {
                    WorkspacePlaceholderCard(
                        icon: "text.badge.sparkles",
                        title: "No cover letter generated yet",
                        subtitle: "Create a role-specific draft from the tracker record, then copy it or download a PDF."
                    )
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: BoostaSpace.sm) {
                        PrimaryButton(title: coverLetter == nil ? "Generate Cover Letter" : "Regenerate Cover Letter") {
                            generateCoverLetter()
                        }

                        SecondaryButton(title: "Copy Text", isDisabled: coverLetter == nil) {
                            copyCoverLetter()
                        }

                        SecondaryButton(title: "Download PDF", isDisabled: coverLetter == nil) {
                            exportCoverLetterPDF()
                        }
                    }

                    VStack(spacing: BoostaSpace.sm) {
                        PrimaryButton(title: coverLetter == nil ? "Generate Cover Letter" : "Regenerate Cover Letter") {
                            generateCoverLetter()
                        }

                        SecondaryButton(title: "Copy Text", isDisabled: coverLetter == nil) {
                            copyCoverLetter()
                        }

                        SecondaryButton(title: "Download PDF", isDisabled: coverLetter == nil) {
                            exportCoverLetterPDF()
                        }
                    }
                }
            }
        }
    }

    private var interviewPrepCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                HStack(alignment: .top, spacing: BoostaSpace.sm) {
                    SectionHeader(
                        title: "Interview Prep",
                        subtitle: "Common questions and focused answer guidance that you can regenerate for a fresh set."
                    )

                    Spacer(minLength: 0)

                    WorkspaceStatusPill(title: interviewPrepLimitStatus.summary, tint: interviewPrepLimitStatus.canUse ? BoostaColor.success : BoostaColor.warning)
                }

                if let interviewPrep {
                    Text(interviewPrep.intro)
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)

                    VStack(spacing: BoostaSpace.sm) {
                        ForEach(interviewPrep.questions) { item in
                            WorkspaceQuestionCard(question: item)
                        }
                    }
                } else {
                    WorkspacePlaceholderCard(
                        icon: "person.crop.rectangle.stack",
                        title: "No interview prep generated yet",
                        subtitle: "Generate a reusable prep pack, then re-run it to get different question angles for the same role."
                    )
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: BoostaSpace.sm) {
                        PrimaryButton(title: interviewPrep == nil ? "Generate Interview Prep" : "Regenerate Questions") {
                            generateInterviewPrep()
                        }

                        SecondaryButton(title: "Open Tailoring") {
                            openTailoringWorkspace(message: "Tailoring workspace opened for deeper role prep.")
                        }
                    }

                    VStack(spacing: BoostaSpace.sm) {
                        PrimaryButton(title: interviewPrep == nil ? "Generate Interview Prep" : "Regenerate Questions") {
                            generateInterviewPrep()
                        }

                        SecondaryButton(title: "Open Tailoring") {
                            openTailoringWorkspace(message: "Tailoring workspace opened for deeper role prep.")
                        }
                    }
                }
            }
        }
    }

    private var documentsCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(
                    title: "Documents",
                    subtitle: "Resume assets, generated files, and recruiter-facing materials for this role."
                )

                VStack(spacing: BoostaSpace.sm) {
                    WorkspaceDocumentCard(
                        icon: "doc.text",
                        title: "Uploaded resume",
                        subtitle: application.resumeUsed ?? "No resume attached to this tracker record yet.",
                        actionTitle: application.resumeUsed == nil ? "Add in Edit" : "Update Resume",
                        action: onEdit
                    )

                    WorkspaceDocumentCard(
                        icon: "wand.and.stars",
                        title: "Tailored version",
                        subtitle: application.atsScore == nil
                            ? "Run Scanner or Tailoring to create a stronger role-specific version."
                            : "ATS signal is already attached to this application. Open Tailoring to export the resume.",
                        actionTitle: "Open Tailoring",
                        action: {
                            openTailoringWorkspace(message: "Tailoring workspace opened for export and refinement.")
                        }
                    )

                    WorkspaceDocumentCard(
                        icon: "doc.richtext",
                        title: "Cover letter PDF",
                        subtitle: coverLetter == nil
                            ? "Generate a cover letter here, then preview and share a PDF."
                            : "Role-specific cover letter is ready to preview, share, or download.",
                        actionTitle: coverLetter == nil ? "Generate" : "Preview PDF",
                        action: {
                            if coverLetter == nil {
                                generateCoverLetter(exportAfterGeneration: true)
                            } else {
                                exportCoverLetterPDF()
                            }
                        }
                    )
                }

                if let jobURL = jobURL {
                    Link(destination: jobURL) {
                        Label("Open Job Post", systemImage: "link")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.accent)
                    }
                }
            }
        }
    }

    private var timelineCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(
                    title: "Timeline",
                    subtitle: "Activity feed that keeps the tracker feeling alive."
                )

                VStack(spacing: BoostaSpace.sm) {
                    ForEach(timelineItems) { item in
                        WorkspaceTimelineRow(item: item)
                    }
                }
            }
        }
    }

    private var notesCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(
                    title: "Notes",
                    subtitle: "Recruiter context, reminders, and conversation hooks kept close."
                )

                VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                    Text(
                        application.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                            ? application.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            : "Add recruiter names, prep reminders, salary context, or any role-specific signal you want easy access to later."
                    )
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.primaryText)

                    HStack(spacing: BoostaSpace.sm) {
                        WorkspaceInfoChip(title: "Source", value: application.source)
                        if let followUpDate {
                            WorkspaceInfoChip(title: "Follow up", value: followUpDate.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }
                .padding(BoostaSpace.md)
                .background(Color(red: 1.0, green: 0.98, blue: 0.84).opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
            }
        }
    }

    private var quickActionsBar: some View {
        GlassCard(padding: BoostaSpace.sm) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 120), spacing: BoostaSpace.sm),
                    GridItem(.flexible(minimum: 120), spacing: BoostaSpace.sm)
                ],
                spacing: BoostaSpace.sm
            ) {
                TrackerQuickActionButton(title: "Tailor Again", systemImage: "wand.and.stars", tint: BoostaColor.accent) {
                    openTailoringWorkspace(message: "Tailoring workspace opened for this application.")
                }

                TrackerQuickActionButton(title: "Export Resume", systemImage: "square.and.arrow.down", tint: BoostaColor.success) {
                    openTailoringWorkspace(message: "Tailoring workspace opened for resume export.")
                }

                TrackerQuickActionButton(title: "Mark Status", systemImage: "arrow.triangle.2.circlepath", tint: BoostaColor.warning) {
                    onChangeStatus()
                }

                TrackerQuickActionButton(title: "Prepare Interview", systemImage: "person.crop.rectangle.stack", tint: BoostaColor.accentSecondary) {
                    generateInterviewPrep()
                }
            }
        }
    }

    private var coverLetterLimitStatus: WorkspaceFeatureLimitStatus {
        subscriptionService.status(for: .coverLetter)
    }

    private var interviewPrepLimitStatus: WorkspaceFeatureLimitStatus {
        subscriptionService.status(for: .interviewPrep)
    }

    private var companyInitials: String {
        let components = application.company
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        return components.joined().isEmpty ? "CV" : components.joined()
    }

    private var journeyStage: TrackerWorkspaceStage {
        let stageFromStatus = stageForCurrentProgress(status: application.status)
        if stageFromStatus.order <= TrackerWorkspaceStage.saved.order,
           coverLetter != nil || application.atsScore != nil {
            return .tailored
        }
        return stageFromStatus
    }

    private var currentATSScore: Int {
        if let atsScore = application.atsScore {
            return min(max(atsScore, 0), 100)
        }

        let resumeBonus = application.resumeUsed?.isEmpty == false ? 8 : 0
        let notesBonus = application.notes?.isEmpty == false ? 5 : 0
        let statusBonus: Int
        switch application.status {
        case .saved:
            statusBonus = 2
        case .applied:
            statusBonus = 7
        case .interview:
            statusBonus = 11
        case .offer:
            statusBonus = 15
        case .rejected:
            statusBonus = 4
        case .archived:
            statusBonus = 3
        }
        return min(96, 64 + resumeBonus + notesBonus + statusBonus)
    }

    private var analyticsTrend: [Double] {
        let current = Double(currentATSScore)
        let base = max(current - Double(12 + max(journeyStage.order - 1, 0) * 3), 52)
        return [
            base,
            min(base + 4, current),
            min(base + 8, current + 1),
            min(base + 10, current),
            current
        ]
    }

    private var scoreImprovement: Int {
        Int((analyticsTrend.last ?? 0) - (analyticsTrend.first ?? 0))
    }

    private var keywordMatchScore: Int {
        min(currentATSScore + 2, 99)
    }

    private var readabilityScore: Int {
        min(max(currentATSScore - 4, 58), 97)
    }

    private var technicalImpactScore: Int {
        min(max(currentATSScore + (application.notes?.isEmpty == false ? 4 : 0) - 1, 60), 99)
    }

    private var topImprovementLabel: String {
        if application.notes?.isEmpty == false {
            return "Technical Impact"
        }
        if application.resumeUsed?.isEmpty == false {
            return "Keyword Match"
        }
        switch application.status {
        case .saved:
            return "Positioning"
        case .applied:
            return "Readability"
        case .interview:
            return "Story Clarity"
        case .offer:
            return "Executive Signal"
        case .rejected, .archived:
            return "Momentum Recovery"
        }
    }

    private var insightItems: [WorkspaceInsight] {
        var insights: [WorkspaceInsight] = [
            .init(
                title: "Add measurable outcomes",
                detail: "Turn one responsibility into a before-and-after result with a number, speed gain, or conversion improvement.",
                tint: BoostaColor.success
            ),
            .init(
                title: "Surface hard skills earlier",
                detail: "Move the strongest technical keywords closer to the top third of the resume so ATS scanners pick them up faster.",
                tint: BoostaColor.accent
            ),
            .init(
                title: "Quantify collaboration",
                detail: "Show who you worked with and what moved because of that collaboration, not just the meeting cadence.",
                tint: BoostaColor.warning
            ),
            .init(
                title: "Sharpen the first pitch",
                detail: "Lead with the outcome you create in this type of role, then back it up with one fast proof point.",
                tint: BoostaColor.accentSecondary
            )
        ]

        if application.notes?.isEmpty == false {
            insights.insert(
                .init(
                    title: "Promote tracker context",
                    detail: "Convert your internal note into one recruiter-facing sentence so important context is not trapped in the tracker.",
                    tint: BoostaColor.success
                ),
                at: 1
            )
        }

        if application.status == .interview || application.status == .offer {
            insights.insert(
                .init(
                    title: "Prepare evidence, not adjectives",
                    detail: "Replace generic strengths with short stories about constraints, decisions, and outcomes you can explain live.",
                    tint: BoostaColor.warning
                ),
                at: 0
            )
        }

        return Array(insights.prefix(4))
    }

    private var timelineItems: [WorkspaceTimelineItem] {
        var items: [WorkspaceTimelineItem] = [
            .init(
                title: application.status == .saved ? "Role captured" : "Application tracked",
                detail: "\(application.company) • \(application.role)",
                date: application.appliedAt,
                tint: BoostaColor.accent
            )
        ]

        if let coverLetter {
            items.append(
                .init(
                    title: "Cover letter generated",
                    detail: "Role-specific draft ready to copy or export as PDF.",
                    date: coverLetter.createdAt,
                    tint: BoostaColor.success
                )
            )
        }

        if let interviewPrep {
            items.append(
                .init(
                    title: "Interview prep refreshed",
                    detail: "\(interviewPrep.questions.count) reusable questions added to the workspace.",
                    date: interviewPrep.createdAt,
                    tint: BoostaColor.accentSecondary
                )
            )
        }

        if application.status != .saved {
            items.append(
                .init(
                    title: "Pipeline advanced",
                    detail: "Current status: \(application.status.rawValue.capitalized).",
                    date: application.appliedAt,
                    tint: statusColor(for: application.status)
                )
            )
        }

        if let interviewAt = application.interviewAt {
            items.append(
                .init(
                    title: "Interview scheduled",
                    detail: interviewAt.formatted(date: .abbreviated, time: .shortened),
                    date: interviewAt,
                    tint: BoostaColor.warning
                )
            )
        }

        if let reflectionDate = application.interviewReflectionSubmittedAt {
            items.append(
                .init(
                    title: "Interview reflection saved",
                    detail: "Post-interview notes and confidence were captured.",
                    date: reflectionDate,
                    tint: BoostaColor.success
                )
            )
        }

        return items.sorted(by: { $0.date > $1.date })
    }

    private var lastActivityDate: Date {
        [
            application.interviewReflectionSubmittedAt,
            application.interviewAt,
            coverLetter?.createdAt,
            interviewPrep?.createdAt,
            application.appliedAt
        ]
        .compactMap { $0 }
        .max() ?? application.appliedAt
    }

    private var followUpDate: Date? {
        guard application.status == .applied else { return nil }
        return Calendar.current.date(byAdding: .day, value: 5, to: application.appliedAt)
    }

    private var jobURL: URL? {
        guard let jobLink = application.jobLink?.trimmingCharacters(in: .whitespacesAndNewlines), !jobLink.isEmpty else {
            return nil
        }
        return URL(string: jobLink)
    }

    private func hydrateWorkspaceState() {
        coverLetter = TrackerWorkspaceArtifactStore.loadCoverLetter(for: application.id)
        interviewPrep = TrackerWorkspaceArtifactStore.loadInterviewPrep(for: application.id)
        selectedStage = journeyStage
    }

    private func stageForCurrentProgress(status: ApplicationStatus) -> TrackerWorkspaceStage {
        switch status {
        case .saved:
            return .saved
        case .applied:
            return .applied
        case .interview:
            return .interview
        case .offer:
            return .offer
        case .rejected, .archived:
            return .applied
        }
    }

    private func selectedStageDate(for stage: TrackerWorkspaceStage) -> Date? {
        let calendar = Calendar.current
        switch stage {
        case .saved:
            return application.appliedAt
        case .tailored:
            if let coverLetter {
                return coverLetter.createdAt
            }
            guard application.atsScore != nil else { return nil }
            return calendar.date(byAdding: .hour, value: 4, to: application.appliedAt)
        case .applied:
            return application.status == .saved ? nil : application.appliedAt
        case .interview:
            return application.interviewAt
        case .offer:
            guard application.status == .offer else { return nil }
            return calendar.date(byAdding: .day, value: 6, to: application.interviewAt ?? application.appliedAt)
        }
    }

    private func selectedStageNote(for stage: TrackerWorkspaceStage) -> String {
        switch stage {
        case .saved:
            return "The role is captured and ready for deeper targeting before energy leaks away."
        case .tailored:
            return coverLetter == nil
                ? "ATS direction is mapped and the story is ready to tighten before sharing."
                : "Your role-specific language and supporting assets are already stronger than a generic application."
        case .applied:
            return "This opportunity is now in motion. Keep visibility high with follow-up timing and sharper recruiter-facing proof."
        case .interview:
            return "Convert your best bullets into stories with stakes, choices, and measurable outcomes you can explain clearly."
        case .offer:
            return "Momentum is high. Protect leverage by comparing compensation, scope, and long-term growth signal."
        }
    }

    private func statusColor(for status: ApplicationStatus) -> Color {
        switch status {
        case .saved:
            return BoostaColor.secondaryText
        case .applied:
            return BoostaColor.accent
        case .interview:
            return BoostaColor.warning
        case .offer:
            return BoostaColor.success
        case .rejected:
            return BoostaColor.danger
        case .archived:
            return BoostaColor.secondaryText
        }
    }

    private func generateCoverLetter(exportAfterGeneration: Bool = false) {
        let status = coverLetterLimitStatus
        guard status.canUse else {
            presentPaywall(for: .coverLetter, status: status)
            return
        }

        let nextVersion = (coverLetter?.version ?? 0) + 1
        let generated = TrackerWorkspaceService.generateCoverLetter(for: application, version: nextVersion)
        coverLetter = generated
        TrackerWorkspaceArtifactStore.saveCoverLetter(generated, for: application.id)
        subscriptionService.recordUse(of: .coverLetter)
        selectedStage = max(journeyStage, .tailored)
        feedbackMessage = "Cover letter refreshed for \(application.company)."
        HapticsService.success()

        if exportAfterGeneration {
            exportCoverLetterPDF()
        }
    }

    private func generateInterviewPrep() {
        let status = interviewPrepLimitStatus
        guard status.canUse else {
            presentPaywall(for: .interviewPrep, status: status)
            return
        }

        let nextVersion = (interviewPrep?.version ?? 0) + 1
        let generated = TrackerWorkspaceService.generateInterviewPrep(for: application, version: nextVersion)
        interviewPrep = generated
        TrackerWorkspaceArtifactStore.saveInterviewPrep(generated, for: application.id)
        subscriptionService.recordUse(of: .interviewPrep)
        feedbackMessage = "Interview prep regenerated with a new question mix."
        HapticsService.success()
    }

    private func copyCoverLetter() {
        guard let coverLetter else {
            generateCoverLetter()
            return
        }

        UIPasteboard.general.string = coverLetter.body
        feedbackMessage = "Cover letter copied to the clipboard."
        HapticsService.success()
    }

    private func exportCoverLetterPDF() {
        guard let coverLetter else {
            generateCoverLetter(exportAfterGeneration: true)
            return
        }

        do {
            let url = try TrackerWorkspaceService.makeCoverLetterPDF(for: application, coverLetter: coverLetter)
            previewDocument = GeneratedPDFPreviewDocument(
                title: "\(application.company) Cover Letter",
                fileURL: url
            )
            feedbackMessage = "Cover letter PDF is ready."
            HapticsService.success()
        } catch {
            feedbackMessage = "Could not generate the cover letter PDF."
        }
    }

    private func openTailoringWorkspace(message: String) {
        appRouter.open(.tailoring)
        feedbackMessage = message
    }

    private func presentPaywall(for feature: WorkspaceDailyFeature, status: WorkspaceFeatureLimitStatus) {
        paywallContext = .workspaceFeatureLimit(feature: feature, resetDate: status.resetDate)
        feedbackMessage = "Today's free \(feature.shortTitle) limit is used. Paid plans unlock more."
        HapticsService.impact(.light)
    }
}

private struct GeneratedPDFPreviewDocument: Identifiable {
    let id = UUID()
    let title: String
    let fileURL: URL
}

private struct GeneratedPDFPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let document: GeneratedPDFPreviewDocument

    var body: some View {
        NavigationStack {
            GeneratedPDFKitView(url: document.fileURL)
                .navigationTitle(document.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: document.fileURL)
                    }
                }
        }
    }
}

private struct GeneratedPDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
}

private enum TrackerWorkspaceStage: String, CaseIterable, Identifiable, Comparable {
    case saved
    case tailored
    case applied
    case interview
    case offer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saved:
            return "Saved"
        case .tailored:
            return "Tailored"
        case .applied:
            return "Applied"
        case .interview:
            return "Interview"
        case .offer:
            return "Offer"
        }
    }

    var icon: String {
        switch self {
        case .saved:
            return "bookmark"
        case .tailored:
            return "wand.and.stars"
        case .applied:
            return "paperplane"
        case .interview:
            return "person.crop.rectangle.stack"
        case .offer:
            return "star"
        }
    }

    var tint: Color {
        switch self {
        case .saved:
            return BoostaColor.secondaryText
        case .tailored:
            return BoostaColor.accentSecondary
        case .applied:
            return BoostaColor.accent
        case .interview:
            return BoostaColor.warning
        case .offer:
            return BoostaColor.success
        }
    }

    var order: Int {
        switch self {
        case .saved:
            return 0
        case .tailored:
            return 1
        case .applied:
            return 2
        case .interview:
            return 3
        case .offer:
            return 4
        }
    }

    static func < (lhs: TrackerWorkspaceStage, rhs: TrackerWorkspaceStage) -> Bool {
        lhs.order < rhs.order
    }
}

private struct WorkspaceInsight: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let tint: Color
}

private struct WorkspaceTimelineItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let date: Date
    let tint: Color
}

private struct WorkspaceHeaderButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticsService.tap()
            action()
        } label: {
            WorkspaceHeaderButtonLabel(title: title, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.plain)
    }
}

private struct WorkspaceHeaderButtonLabel: View {
    let title: String
    let systemImage: String
    var tint: Color = BoostaColor.accent

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(BoostaType.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, BoostaSpace.sm)
            .padding(.vertical, 10)
            .background(BoostaColor.surfaceInteractive)
            .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.sm, style: .continuous))
    }
}

private struct WorkspaceStatusPill: View {
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

private struct WorkspaceInfoChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(BoostaColor.tertiaryText)
            Text(value)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.primaryText)
        }
        .padding(.horizontal, BoostaSpace.sm)
        .padding(.vertical, 10)
        .background(BoostaColor.surfaceInteractive)
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.sm, style: .continuous))
    }
}

private struct ProgressStageNode: View {
    let stage: TrackerWorkspaceStage
    let isSelected: Bool
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticsService.selection()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: stage.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isCompleted ? .white : stage.tint)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isCompleted ? stage.tint : stage.tint.opacity(0.14))
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isSelected ? stage.tint : Color.clear, lineWidth: 2)
                    )

                Text(stage.title)
                    .font(BoostaType.caption)
                    .foregroundStyle(isSelected ? BoostaColor.primaryText : BoostaColor.secondaryText)
            }
            .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
    }
}

private struct WorkspaceInsightCard: View {
    let insight: WorkspaceInsight

    var body: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.xs) {
            WorkspaceStatusPill(title: insight.title, tint: insight.tint)
            Text(insight.detail)
                .font(BoostaType.body)
                .foregroundStyle(BoostaColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BoostaSpace.md)
        .background(BoostaColor.surfaceInteractive)
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
    }
}

private struct WorkspaceQuestionCard: View {
    let question: InterviewPrepQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.xs) {
            HStack {
                WorkspaceStatusPill(title: question.focus, tint: BoostaColor.accentSecondary)
                Spacer(minLength: 0)
            }

            Text(question.question)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)

            Text(question.answer)
                .font(BoostaType.body)
                .foregroundStyle(BoostaColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BoostaSpace.md)
        .background(BoostaColor.surfaceInteractive)
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
    }
}

private struct WorkspacePlaceholderCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: BoostaSpace.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BoostaColor.accent)
                .frame(width: 40, height: 40)
                .background(BoostaColor.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: BoostaSpace.xxs) {
                Text(title)
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.primaryText)
                Text(subtitle)
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BoostaSpace.md)
        .background(BoostaColor.surfaceInteractive)
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
    }
}

private struct WorkspaceDocumentCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.sm) {
            HStack(alignment: .top, spacing: BoostaSpace.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BoostaColor.accent)
                    .frame(width: 40, height: 40)
                    .background(BoostaColor.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(BoostaType.bodyStrong)
                        .foregroundStyle(BoostaColor.primaryText)
                    Text(subtitle)
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SecondaryButton(title: actionTitle, action: action)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BoostaSpace.md)
        .background(BoostaColor.surfaceInteractive)
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
    }
}

private struct WorkspaceTimelineRow: View {
    let item: WorkspaceTimelineItem

    var body: some View {
        HStack(alignment: .top, spacing: BoostaSpace.sm) {
            Circle()
                .fill(item.tint)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.primaryText)
                Text(item.detail)
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(BoostaType.caption)
                    .foregroundStyle(item.tint)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}

private struct TrackerQuickActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticsService.tap()
            action()
        } label: {
            HStack(spacing: BoostaSpace.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(BoostaType.bodyStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct TrackerTrendChart: View {
    let points: [Double]
    let tint: Color

    @State private var isVisible = false

    var body: some View {
        GeometryReader { proxy in
            let chartPoints = makePoints(size: proxy.size)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.16),
                                BoostaColor.surfaceInteractive
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                areaPath(points: chartPoints, size: proxy.size)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.28),
                                tint.opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(isVisible ? 1 : 0.1)

                smoothPath(points: chartPoints)
                    .trim(from: 0, to: isVisible ? 1 : 0.05)
                    .stroke(
                        tint,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                    )

                ForEach(Array(chartPoints.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(tint)
                        .frame(width: 8, height: 8)
                        .position(point)
                }
            }
        }
        .onAppear {
            withAnimation(BoostaMotion.slowReveal) {
                isVisible = true
            }
        }
    }

    private func makePoints(size: CGSize) -> [CGPoint] {
        guard points.count > 1 else { return [] }

        let minValue = points.min() ?? 0
        let maxValue = points.max() ?? 1
        let range = max(maxValue - minValue, 1)

        return points.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(max(points.count - 1, 1)) * max(size.width - 8, 0) + 4
            let normalized = (value - minValue) / range
            let y = size.height - (CGFloat(normalized) * max(size.height - 24, 0)) - 12
            return CGPoint(x: x, y: y)
        }
    }

    private func smoothPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: first)

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midPoint = CGPoint(
                x: (previous.x + current.x) / 2,
                y: (previous.y + current.y) / 2
            )

            path.addQuadCurve(to: midPoint, control: controlPoint(previous, current))
            path.addQuadCurve(to: current, control: controlPoint(midPoint, current))
        }

        return path
    }

    private func areaPath(points: [CGPoint], size: CGSize) -> Path {
        var path = smoothPath(points: points)
        guard let last = points.last, let first = points.first else { return path }
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }

    private func controlPoint(_ point1: CGPoint, _ point2: CGPoint) -> CGPoint {
        CGPoint(x: (point1.x + point2.x) / 2, y: point1.y)
    }
}
