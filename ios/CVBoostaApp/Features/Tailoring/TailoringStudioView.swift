import SwiftUI

struct TailoringStudioView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    @State private var selectedResumeID: UUID?
    @State private var jobTitle: String = ""
    @State private var companyName: String = ""
    @State private var jobDescription: String = ""
    @State private var tone: Tone = .professional

    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var result: TailoringGenerateResponse?

    private let service = TailoringAPIService.shared

    enum Tone: String, CaseIterable {
        case professional = "Professional"
        case confident = "Confident"
        case concise = "Concise"
        case technical = "Technical"
        case executive = "Executive"
    }

    private var canSubmit: Bool {
        !jobTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isGenerating
    }

    private var displayedRewrites: [String] {
        guard let rewrites = result?.bulletRewrites else { return [] }
        return subscriptionService.isPremium ? rewrites : Array(rewrites.prefix(3))
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

                ScrollView {
                    VStack(spacing: BoostaSpace.md) {
                        formCard

                        PrimaryButton(
                            title: isGenerating ? "Generating..." : "Generate Preview",
                            isLoading: isGenerating,
                            isDisabled: !canSubmit
                        ) {
                            Task {
                                await generate()
                            }
                        }

                        if let errorMessage {
                            ErrorBanner(message: errorMessage)
                        }

                        if let result {
                            outputCard(result)
                        }
                    }
                    .padding(BoostaSpace.md)
                }
            }
            .navigationTitle("Tailoring")
        }
    }

    private var formCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "Quick Tailoring",
                    subtitle: "Get a mobile preview. Finish deep tailoring on the website."
                )

                Picker("Select saved resume", selection: $selectedResumeID) {
                    Text("Upload new resume").tag(nil as UUID?)
                    ForEach(authViewModel.me?.savedResumes ?? []) { resume in
                        Text(resume.fileName).tag(Optional(resume.id))
                    }
                }
                .pickerStyle(.menu)

                TextInputField(
                    title: "Job title",
                    placeholder: "Marketing Manager",
                    text: $jobTitle,
                    textContentType: .jobTitle
                )

                TextInputField(
                    title: "Company name",
                    placeholder: "Google",
                    text: $companyName
                )

                VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                    Text("Job description")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                    TextEditor(text: $jobDescription)
                        .frame(minHeight: 140)
                        .padding(BoostaSpace.xs)
                        .background(Color.white.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                                .stroke(BoostaColor.glassStroke, lineWidth: 1)
                        )
                }

                Picker("Tone", selection: $tone) {
                    ForEach(Tone.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func outputCard(_ result: TailoringGenerateResponse) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "Tailoring Preview",
                    subtitle: "For full editing, exports, and versions use CVBoosta web."
                )

                Text("Tailored summary")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
                Text(result.tailoredSummary)
                    .font(BoostaType.body)

                Divider()

                Text("Suggested bullet rewrites")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
                ForEach(displayedRewrites, id: \.self) { item in
                    Text("• \(item)")
                        .font(BoostaType.body)
                }

                if !subscriptionService.isPremium && result.bulletRewrites.count > 3 {
                    Text("Free plan preview: first 3 suggestions shown.")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.warning)
                }

                Divider()

                Text("Missing keywords")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(result.missingKeywords, id: \.self) { keyword in
                        KeywordChip(text: keyword, status: .missing)
                    }
                }

                Divider()

                PrimaryButton(title: "Continue on Web") {
                    openURL(AppEnvironment.webBaseURL)
                }
            }
        }
    }

    private func generate() async {
        errorMessage = nil
        result = nil
        isGenerating = true
        defer { isGenerating = false }

        let payload = TailoringGenerateRequest(
            resumeId: selectedResumeID,
            resumeText: nil,
            jobTitle: jobTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            companyName: companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : companyName,
            jobDescription: jobDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            tone: tone.rawValue
        )

        do {
            result = try await service.generate(payload)
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    TailoringStudioView()
        .environmentObject(AuthViewModel())
}
