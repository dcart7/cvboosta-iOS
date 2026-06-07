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
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: .now) ?? .now
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

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CVBoostaProvider()) { entry in
            StreakWidgetView(entry: entry)
                .widgetURL(URL(string: "cvboosta://home"))
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Career Streak")
        .description("Keep your daily career streak visible so momentum never disappears.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct InterviewCountdownWidget: Widget {
    let kind = "InterviewCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CVBoostaProvider()) { entry in
            InterviewCountdownWidgetView(entry: entry)
                .widgetURL(URL(string: "cvboosta://tracker"))
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Interview Countdown")
        .description("See the real time left until your next interview.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
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
                    WidgetPill(title: entry.snapshot.streakDays == 0 ? "Start streak" : "\(entry.snapshot.streakDays)d streak", tint: .orange)
                }
                Spacer(minLength: 0)
                Label("Open Scanner", systemImage: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CVBoostaWidgetEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot.streakDays == 0 ? "Start streak" : "\(entry.snapshot.streakDays)d streak")
                    .font(.headline)
                Text(entry.snapshot.streakStatusTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 10) {
                widgetTitle("Career Streak", subtitle: entry.snapshot.careerLevel)
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: min(max(Double(entry.snapshot.streakDays) / 30.0, 0.08), 1))
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text(entry.snapshot.streakDays == 0 ? "0" : "\(entry.snapshot.streakDays)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                    }
                    .frame(width: 74, height: 74)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.snapshot.streakStatusTitle)
                            .font(.subheadline.weight(.semibold))
                        Text(entry.snapshot.streakStatusDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        WidgetPill(title: entry.snapshot.nextMilestoneTitle, tint: .orange)
                    }
                }
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                widgetTitle("Career Streak", subtitle: entry.snapshot.weeklyActiveDays == 0 ? "1 action today" : "\(entry.snapshot.weeklyActiveDays)/7 this week")
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.snapshot.streakDays == 0 ? "Start today" : "\(entry.snapshot.streakDays) day streak")
                            .font(.title3.bold())
                        Text(entry.snapshot.streakStatusTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(entry.snapshot.streakStatusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }
}

private struct InterviewCountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CVBoostaWidgetEntry

    var body: some View {
        if let interviewDate = entry.snapshot.nextInterviewDate,
           let title = entry.snapshot.nextInterviewTitle {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interview")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(timerInterval: Date()...interviewDate, countsDown: true)
                        .font(.headline)
                    Text(entry.snapshot.nextInterviewCompany ?? title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            case .systemSmall:
                VStack(alignment: .leading, spacing: 10) {
                    widgetTitle("Interview", subtitle: entry.snapshot.nextInterviewCompany ?? "Countdown")
                    Spacer(minLength: 0)
                    Text(timerInterval: Date()...interviewDate, countsDown: true)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text(interviewDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            default:
                VStack(alignment: .leading, spacing: 10) {
                    widgetTitle("Interview Countdown", subtitle: title)
                    Text(timerInterval: Date()...interviewDate, countsDown: true)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text(interviewDate.formatted(date: .complete, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("Open Tracker", systemImage: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                widgetTitle("Interview Countdown", subtitle: "No interview scheduled")
                Text("Add an interview date in Tracker to see a live countdown here.")
                    .font(.caption)
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
        StreakWidget()
        InterviewCountdownWidget()
        PipelineWidget()
        CareerMomentumWidget()
    }
}
