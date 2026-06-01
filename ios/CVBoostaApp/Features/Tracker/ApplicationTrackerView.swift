import SwiftUI
import SwiftData

struct ApplicationTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse) private var applications: [ApplicationRecord]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                List {
                    ForEach(applications) { app in
                        VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                            Text(app.company)
                                .font(BoostaType.bodyStrong)
                            Text(app.role)
                                .font(BoostaType.body)
                            Text(app.status.rawValue.capitalized)
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                        }
                        .padding(.vertical, BoostaSpace.xs)
                        .listRowBackground(Color.white.opacity(0.45))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Applications")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addSample()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private func addSample() {
        HapticsService.impact(.light)
        let sample = ApplicationRecord(
            company: "Stripe",
            role: "Senior Product Manager",
            status: .applied,
            source: "Referral"
        )
        modelContext.insert(sample)
    }
}

#Preview {
    ApplicationTrackerView()
        .modelContainer(PreviewModelContainer.shared)
}
