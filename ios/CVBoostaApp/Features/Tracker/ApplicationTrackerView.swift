import SwiftUI

struct ApplicationTrackerView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var applications: [JobApplication] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddSheet = false

    private let service = ApplicationAPIService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading applications...")
                } else if applications.isEmpty {
                    VStack {
                        EmptyStateView(
                            title: "No applications yet",
                            message: "Track job applications and interviews in one place.",
                            actionTitle: "Add Application"
                        ) {
                            showAddSheet = true
                        }
                    }
                    .padding(BoostaSpace.md)
                } else {
                    ScrollView {
                        VStack(spacing: BoostaSpace.sm) {
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
                    AddApplicationView(resumeNames: authViewModel.me?.savedResumes.map(\.fileName) ?? []) { payload in
                        Task {
                            await createApplication(payload)
                        }
                    }
                }
            }
            .task {
                await loadApplications()
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

    private func applicationCard(_ app: JobApplication) -> some View {
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

                    Text(app.status.capitalized)
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

    private func nextStep(for status: String) -> String {
        switch status.lowercased() {
        case "saved":
            return "Submit application"
        case "applied":
            return "Follow up in 5 days"
        case "interview":
            return "Prepare interview examples"
        case "offer":
            return "Review offer terms"
        case "rejected":
            return "Retrospective and apply next"
        default:
            return "Update application"
        }
    }

    private func loadApplications() async {
        isLoading = true
        defer { isLoading = false }

        do {
            applications = try await service.fetchApplications()
            errorMessage = nil
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createApplication(_ payload: CreateApplicationRequest) async {
        do {
            let created = try await service.createApplication(payload)
            applications.insert(created, at: 0)
            showAddSheet = false
            errorMessage = nil
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AddApplicationView: View {
    @Environment(\.dismiss) private var dismiss

    let resumeNames: [String]
    let onSave: (CreateApplicationRequest) -> Void

    @State private var company = ""
    @State private var role = ""
    @State private var jobLink = ""
    @State private var status: TrackerStatus = .saved
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
                        TextInputField(title: "Job link", placeholder: "https://...", text: $jobLink, keyboardType: .URL, autocapitalization: .never)

                        Picker("Status", selection: $status) {
                            ForEach(TrackerStatus.allCases, id: \.self) { item in
                                Text(item.title).tag(item)
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
                            let payload = CreateApplicationRequest(
                                company: company.trimmingCharacters(in: .whitespacesAndNewlines),
                                role: role.trimmingCharacters(in: .whitespacesAndNewlines),
                                status: status.rawValue,
                                source: "iOS",
                                appliedAt: appliedAt,
                                interviewAt: hasInterviewDate ? interviewDate : nil,
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                                resumeUsed: selectedResume.isEmpty ? nil : selectedResume,
                                jobLink: jobLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : jobLink
                            )
                            onSave(payload)
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

#Preview {
    ApplicationTrackerView()
        .environmentObject(AuthViewModel())
}
