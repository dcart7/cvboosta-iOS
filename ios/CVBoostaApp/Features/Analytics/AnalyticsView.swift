import SwiftUI
import Charts

struct AnalyticsView: View {
    private let points: [AnalyticsPoint] = [
        .init(day: "Mon", ats: 64, apps: 1),
        .init(day: "Tue", ats: 67, apps: 2),
        .init(day: "Wed", ats: 71, apps: 2),
        .init(day: "Thu", ats: 74, apps: 3),
        .init(day: "Fri", ats: 78, apps: 4),
        .init(day: "Sat", ats: 79, apps: 1),
        .init(day: "Sun", ats: 82, apps: 3)
    ]

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
                        GlassCard {
                            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                                Text("ATS Trend")
                                    .font(BoostaType.section)

                                Chart(points) { point in
                                    LineMark(
                                        x: .value("Day", point.day),
                                        y: .value("ATS", point.ats)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(BoostaColor.accent)

                                    AreaMark(
                                        x: .value("Day", point.day),
                                        y: .value("ATS", point.ats)
                                    )
                                    .foregroundStyle(BoostaColor.accent.opacity(0.18))
                                }
                                .frame(height: 180)
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                                Text("Application Velocity")
                                    .font(BoostaType.section)

                                Chart(points) { point in
                                    BarMark(
                                        x: .value("Day", point.day),
                                        y: .value("Applications", point.apps)
                                    )
                                    .foregroundStyle(BoostaColor.success)
                                    .cornerRadius(4)
                                }
                                .frame(height: 180)
                            }
                        }
                    }
                    .padding(BoostaSpace.md)
                }
            }
            .navigationTitle("Career Analytics")
        }
    }
}

private struct AnalyticsPoint: Identifiable {
    let id = UUID()
    let day: String
    let ats: Int
    let apps: Int
}

#Preview {
    AnalyticsView()
}
