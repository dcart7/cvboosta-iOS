import SwiftUI

struct AccountHistoryView: View {
    @State private var historyItems: [HistoryListItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var previewDocument: HistoryPDFPreviewDocument?

    private let resumeService = ResumeService.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Group {
                if historyItems.isEmpty, isLoading {
                    ProgressView("Loading history...")
                        .tint(BoostaColor.accent)
                } else if historyItems.isEmpty {
                    EmptyStateView(
                        title: "No history yet",
                        message: "Your shared CVBoosta account history will appear here after scans and optimizations.",
                        actionTitle: "Refresh"
                    ) {
                        Task { await loadHistory() }
                    }
                    .padding(BoostaSpace.md)
                } else {
                    ScrollView {
                        LazyVStack(spacing: BoostaSpace.sm) {
                            ForEach(historyItems) { item in
                                Button {
                                    Task { await openHistoryPDF(for: item) }
                                } label: {
                                    historyRow(item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(BoostaSpace.md)
                    }
                }
            }
        }
        .navigationTitle("Account History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadHistory() }
                } label: {
                    Image(systemName: "arrow.clockwise")
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
        .sheet(item: $previewDocument) { document in
            HistoryPDFPreviewSheet(document: document)
        }
        .task {
            await loadHistory()
        }
    }

    private func historyRow(_ item: HistoryListItem) -> some View {
        GlassCard {
            HStack(spacing: BoostaSpace.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.role ?? "CV Optimization")
                        .font(BoostaType.bodyStrong)
                        .foregroundStyle(BoostaColor.primaryText)
                    if let company = item.company, !company.isEmpty {
                        Text(company)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("ATS")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                    Text("\(item.matchAfter ?? item.score)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(BoostaColor.accent)
                }
            }
        }
    }

    private func loadHistory() async {
        isLoading = true
        defer { isLoading = false }

        do {
            historyItems = try await resumeService.history().sorted { $0.createdAt > $1.createdAt }
            errorMessage = nil
        } catch {
            errorMessage = "Could not load full account history."
        }
    }

    private func openHistoryPDF(for item: HistoryListItem) async {
        do {
            let detail = try await resumeService.historyDetail(id: item.id)
            let watermarkText = await MainActor.run {
                SubscriptionService.shared.isPremium ? nil : SharedHistoryPDFBuilder.freeWatermarkText
            }
            let url = try SharedHistoryPDFBuilder.makeResumePDF(
                item: item,
                detail: detail,
                watermarkText: watermarkText
            )
            previewDocument = HistoryPDFPreviewDocument(
                id: item.id,
                title: item.role ?? "CV Optimization",
                fileURL: url,
                resumeName: SharedHistoryPDFBuilder.resumeName(for: item, detail: detail),
                optimizedText: detail.optimizedCV,
                watermarkText: watermarkText
            )
            errorMessage = nil
        } catch {
            errorMessage = "Could not open history item."
        }
    }
}

#Preview {
    NavigationStack {
        AccountHistoryView()
    }
}
