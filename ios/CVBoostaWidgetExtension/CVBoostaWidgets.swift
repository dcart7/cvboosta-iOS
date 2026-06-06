import WidgetKit
import SwiftUI

struct CVBoostaWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: CVBoostaWidgetSnapshot
}

struct CVBoostaProvider: TimelineProvider {
    func placeholder(in context: Context) -> CVBoostaWidgetEntry {
        CVBoostaWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CVBoostaWidgetEntry) -> Void) {
        completion(CVBoostaWidgetEntry(date: .now, snapshot: CVBoostaWidgetStore.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CVBoostaWidgetEntry>) -> Void) {
        let entry = CVBoostaWidgetEntry(date: .now, snapshot: CVBoostaWidgetStore.loadSnapshot())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct ATSScoreWidget: Widget {
    let kind = "ATSScoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CVBoostaProvider()) { entry in
            ATSScoreWidgetView(entry: entry)
                .widgetURL(URL(string: "cvboosta://scanner"))
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("ATS Score")
        .description("See ATS health, missing keywords, and your latest score at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct DailyFocusWidget: Widget {
    let kind = "DailyFocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CVBoostaProvider()) { entry in
            DailyFocusWidgetView(entry: entry)
                .widgetURL(URL(string: "cvboosta://scanner"))
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Daily Focus")
        .description("Turn resume optimization into one clear next step every day.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct PipelineWidget: Widget {
    let kind = "PipelineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CVBoostaProvider()) { entry in
            PipelineWidgetView(entry: entry)
                .widgetURL(URL(string: "cvboosta://tracker"))
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Job Pipeline")
        .description("Keep your applications, interviews, and offers visible all the time.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct CareerMomentumWidget: Widget {
    let kind = "CareerMomentumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CVBoostaProvider()) { entry in
            CareerMomentumWidgetView(entry: entry)
                .widgetURL(URL(string: "cvboosta://home"))
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Career Momentum")
        .description("Track growth, streaks, and whether your job search is moving forward.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct ATSScoreWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CVBoostaWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Gauge(value: Double(entry.snapshot.currentATSScore), in: 0...100) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(entry.snapshot.currentATSScore)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(scoreColor)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("ATS \(entry.snapshot.currentATSScore)")
                    .font(.headline)
                Text(entry.snapshot.weeklyATSDelta == 0 ? "Stable this week" : "\(entry.snapshot.weeklyATSDelta > 0 ? "+" : "")\(entry.snapshot.weeklyATSDelta) this week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 10) {
                widgetTitle("ATS Score", subtitle: recencyText)
                HStack(spacing: 14) {
                    scoreGauge
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Missing keywords")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(keywordLine)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        if let recentRole = entry.snapshot.recentRole {
                            Text(recentRole)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                widgetTitle("ATS Score", subtitle: entry.snapshot.weeklyATSDelta == 0 ? "No change this week" : "\(entry.snapshot.weeklyATSDelta > 0 ? "+" : "")\(entry.snapshot.weeklyATSDelta) this week")
                scoreGauge
                    .frame(maxWidth: .infinity)
                Text(keywordLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var scoreGauge: some View {
        Gauge(value: Double(entry.snapshot.currentATSScore), in: 0...100) {
            EmptyView()
        } currentValueLabel: {
            VStack(spacing: 2) {
                Text("\(entry.snapshot.currentATSScore)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("ATS")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(scoreColor)
    }

    private var keywordLine: String {
        let keywords = entry.snapshot.missingKeywords
        return keywords.isEmpty ? "No urgent keyword gaps detected." : keywords.joined(separator: ", ")
    }

    private var recencyText: String {
        guard let recentScanDate = entry.snapshot.recentScanDate else { return "Latest scan unavailable" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Updated \(formatter.localizedString(for: recentScanDate, relativeTo: .now))"
    }

    private var scoreColor: Color {
        switch entry.snapshot.currentATSScore {
        case 80...100: return .green
        case 60...79: return .orange
        default: return .blue
        }
    }
}

private struct DailyFocusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CVBoostaWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetTitle(entry.snapshot.dailyFocusTitle, subtitle: family == .accessoryRectangular ? "Open Scanner" : "One smart next step")
            Text(entry.snapshot.dailyFocusDetail)
                .font(family == .systemLarge ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                .lineLimit(family == .systemLarge ? 4 : 3)
            if family != .accessoryRectangular {
                HStack(spacing: 8) {
                    WidgetPill(title: entry.snapshot.recentRole ?? "ATS", tint: .blue)
                    WidgetPill(title: entry.snapshot.streakDays == 0 ? "Start streak" : "\(entry.snapshot.streakDays)d streak", tint: .purple)
                }
                Spacer(minLength: 0)
                Label("Open Scanner", systemImage: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PipelineWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CVBoostaWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetTitle("Job Pipeline", subtitle: pipelineSubtitle)

            HStack(spacing: 10) {
                pipelineMetric("Applied", value: entry.snapshot.applicationsCount, tint: .blue)
                pipelineMetric("Interviews", value: entry.snapshot.interviewsCount, tint: .orange)
                pipelineMetric("Offers", value: entry.snapshot.offersCount, tint: .green)
            }

            GeometryReader { proxy in
                HStack(spacing: 8) {
                    pipelineBar(value: entry.snapshot.applicationsCount, maxCount: maxCount, color: .blue, width: proxy.size.width)
                    pipelineBar(value: entry.snapshot.interviewsCount, maxCount: maxCount, color: .orange, width: proxy.size.width)
                    pipelineBar(value: entry.snapshot.offersCount, maxCount: maxCount, color: .green, width: proxy.size.width)
                }
            }
            .frame(height: 12)

            if family == .systemLarge {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.snapshot.nextInterviewTitle ?? "No interview scheduled")
                        .font(.subheadline.weight(.semibold))
                    Text(nextInterviewDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Response rate \(entry.snapshot.responseRate)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var maxCount: Int {
        max(entry.snapshot.applicationsCount, max(entry.snapshot.interviewsCount, max(entry.snapshot.offersCount, 1)))
    }

    private var pipelineSubtitle: String {
        entry.snapshot.responseRate == 0 ? "Track the real path to interviews" : "Response rate \(entry.snapshot.responseRate)%"
    }

    private func pipelineMetric(_ title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pipelineBar(value: Int, maxCount: Int, color: Color, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 999, style: .continuous)
            .fill(color.opacity(0.85))
            .frame(width: Swift.max(CGFloat(value) / CGFloat(maxCount) * (width / 3 - 10), 10))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.white.opacity(0.15))
            )
    }

    private var nextInterviewDetail: String {
        guard let nextInterviewDate = entry.snapshot.nextInterviewDate else {
            return "Add interview dates in Tracker to surface reminders here."
        }
        return nextInterviewDate.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct CareerMomentumWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CVBoostaWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetTitle(entry.snapshot.momentumTitle, subtitle: momentumBadge)
            Text(entry.snapshot.momentumDetail)
                .font(family == .systemSmall ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .lineLimit(family == .systemSmall ? 3 : 4)

            if family != .systemSmall {
                HStack(spacing: 8) {
                    WidgetPill(title: "Best: \(entry.snapshot.strongestArea)", tint: .green)
                    WidgetPill(title: "Blocker: \(entry.snapshot.weakestArea)", tint: .orange)
                }
            }

            if family == .systemLarge {
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    statColumn(title: "ATS", value: entry.snapshot.currentATSScore == 0 ? "—" : "\(entry.snapshot.currentATSScore)")
                    statColumn(title: "Streak", value: entry.snapshot.streakDays == 0 ? "0" : "\(entry.snapshot.streakDays)d")
                    statColumn(title: "Apps", value: "\(entry.snapshot.applicationsCount)")
                }
            }
        }
    }

    private var momentumBadge: String {
        if entry.snapshot.weeklyATSDelta > 0 { return "Improving" }
        if entry.snapshot.currentATSScore >= 80 { return "Strong" }
        return "In progress"
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.08, green: 0.13, blue: 0.28), Color(red: 0.15, green: 0.24, blue: 0.46)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct WidgetPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.16))
            .clipShape(Capsule())
    }
}

@ViewBuilder
private func widgetTitle(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        Text(subtitle)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}

@main
struct CVBoostaWidgetBundle: WidgetBundle {
    var body: some Widget {
        CVBoostaLiveActivity()
        ATSScoreWidget()
        DailyFocusWidget()
        PipelineWidget()
        CareerMomentumWidget()
    }
}
