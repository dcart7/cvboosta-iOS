import SwiftUI
import SwiftData

struct ApplicationTrackerView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var applications: [ApplicationRecord]

    @State private var errorMessage: String?
    @State private var showAddSheet = false

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
            .overlay(alignment: .top) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                        .padding(.horizontal, BoostaSpace.md)
                        .padding(.top, BoostaSpace.sm)
                }
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

                Text(responseRate == 0 ? "Start tracking applications to unlock conversion insights." : "Current response rate: \(responseRate)%")
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private func applicationCard(_ app: ApplicationRecord) -> some View {
        GlassCard {
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

                    Text(app.status.rawValue.capitalized)
                        .font(BoostaType.caption)
                        .padding(.horizontal, BoostaSpace.xs)
                        .padding(.vertical, BoostaSpace.xxs)
                        .background(Color.white.opacity(0.65))
                        .clipShape(Capsule())
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

                Text("Next step: \(nextStep(for: app.status))")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.primaryText)
            }
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
            showAddSheet = false
        } catch {
            errorMessage = "Could not save application."
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

struct AddApplicationView: View {
    @Environment(\.dismiss) private var dismiss

    let resumeNames: [String]
    let onSave: (NewApplicationDraft) -> Void

    @State private var company = ""
    @State private var role = ""
    @State private var jobLink = ""
    @State private var status: ApplicationStatus = .saved
    @State private var appliedAt: Date = .now
    @State private var selectedResume: String = ""
    @State private var notes = ""
    @State private var hasInterviewDate = false
    @State private var interviewDate: Date = .now

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

                        PrimaryButton(title: "Save Application", isDisabled: !canSave) {
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
                    }
                }
                .padding(BoostaSpace.md)
            }
        }
        .navigationTitle("Add Application")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
    }
}
