import WidgetKit
import SwiftUI

struct CVBoostaWidgetEntry: TimelineEntry {
    let date: Date
    let atsScore: Int
    let applicationsToday: Int
    let streakDays: Int
    let nextInterview: String
}

struct CVBoostaProvider: TimelineProvider {
    func placeholder(in context: Context) -> CVBoostaWidgetEntry {
        CVBoostaWidgetEntry(date: .now, atsScore: 82, applicationsToday: 3, streakDays: 11, nextInterview: "Tomorrow 13:00")
    }

    func getSnapshot(in context: Context, completion: @escaping (CVBoostaWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CVBoostaWidgetEntry>) -> Void) {
        let entry = placeholder(in: context)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct ATSScoreWidget: Widget {
    let kind = "ATSScoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CVBoostaProvider()) { entry in
            VStack(alignment: .leading, spacing: 6) {
                Text("ATS Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(entry.atsScore)")
                    .font(.title2.bold())
                ProgressView(value: Double(entry.atsScore) / 100)
                    .tint(.blue)
            }
            .padding()
        }
        .configurationDisplayName("ATS Score")
        .description("Track resume ATS compatibility.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct DailyApplicationsWidget: Widget {
    let kind = "DailyApplicationsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CVBoostaProvider()) { entry in
            VStack(alignment: .leading, spacing: 6) {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(entry.applicationsToday) sent")
                    .font(.title3.bold())
                Text("Keep the streak alive")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .configurationDisplayName("Daily Applications")
        .description("Track applications sent today.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CVBoostaProvider()) { entry in
            VStack(alignment: .leading, spacing: 6) {
                Text("Job Search Streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(entry.streakDays) days")
                    .font(.title3.bold())
                Text("Consistency compounds")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .configurationDisplayName("Streak")
        .description("Stay consistent with job search actions.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct InterviewCountdownWidget: Widget {
    let kind = "InterviewCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CVBoostaProvider()) { entry in
            VStack(alignment: .leading, spacing: 6) {
                Text("Next Interview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.nextInterview)
                    .font(.headline)
                    .lineLimit(1)
                Text("Prepare now")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .configurationDisplayName("Interview Countdown")
        .description("Never miss your next interview window.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .systemMedium])
    }
}

@main
struct CVBoostaWidgetBundle: WidgetBundle {
    var body: some Widget {
        CVBoostaLiveActivity()
        ATSScoreWidget()
        DailyApplicationsWidget()
        StreakWidget()
        InterviewCountdownWidget()
    }
}
