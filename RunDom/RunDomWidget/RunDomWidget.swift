import WidgetKit
import SwiftUI

struct WeeklySummaryEntry: TimelineEntry {
    let date: Date
    let summary: WeeklySummary
}

struct WeeklySummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklySummaryEntry {
        WeeklySummaryEntry(date: Date(), summary: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeeklySummaryEntry) -> Void) {
        completion(WeeklySummaryEntry(date: Date(), summary: loadSummary()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklySummaryEntry>) -> Void) {
        let now = Date()
        let entry = WeeklySummaryEntry(date: now, summary: loadSummary())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadSummary() -> WeeklySummary {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier) else {
            print("🟥 [Widget] suiteName failed — App Group entitlement missing on widget")
            return .empty
        }
        guard let data = defaults.data(forKey: AppGroup.weeklySummaryKey) else {
            print("🟧 [Widget] no data at key — app hasn't written yet")
            return .empty
        }
        guard let summary = try? JSONDecoder().decode(WeeklySummary.self, from: data) else {
            print("🟥 [Widget] decode failed — bytes=\(data.count)")
            return .empty
        }
        print("🟩 [Widget] LOADED summary: trail=\(summary.totalTrail) runs=\(summary.runCount)")
        return summary
    }
}

struct RunDomWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeeklySummaryEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(summary: entry.summary)
        default:
            MediumWidgetView(summary: entry.summary)
        }
    }
}

private struct SmallWidgetView: View {
    let summary: WeeklySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("widget.thisWeek".widgetLocalized)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 0)

            Text("\(summary.totalTrail)")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("widget.points".widgetLocalized)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            BackgroundGradient(hex: summary.userColorHex)
        }
        .widgetURL(URL(string: "rundom://stats"))
    }
}

private struct MediumWidgetView: View {
    let summary: WeeklySummary

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("widget.thisWeek".widgetLocalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.85))

                Text("\(summary.totalTrail)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("widget.points".widgetLocalized)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 10) {
                MetricRow(
                    icon: "figure.run",
                    value: distanceText,
                    label: "widget.distance".widgetLocalized
                )
                MetricRow(
                    icon: "flag.checkered",
                    value: "\(summary.runCount)",
                    label: runCountLabel
                )
                MetricRow(
                    icon: "flame.fill",
                    value: "\(summary.streakDays)",
                    label: "widget.streak".widgetLocalized
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            BackgroundGradient(hex: summary.userColorHex)
        }
        .widgetURL(URL(string: "rundom://stats"))
    }

    private var distanceText: String {
        let km = summary.totalDistanceMeters / 1000.0
        return String(format: "%.1f", km)
    }

    private var runCountLabel: String {
        summary.runCount == 1
            ? "widget.runCount.single".widgetLocalized
            : "widget.runCount.multiple".widgetLocalized
    }
}

private struct MetricRow: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 16)

            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct BackgroundGradient: View {
    let hex: String

    var body: some View {
        let base = Color(hex: hex) ?? Color(hex: WeeklySummary.empty.userColorHex) ?? .accentColor
        LinearGradient(
            colors: [base, base.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension String {
    var widgetLocalized: String {
        NSLocalizedString(self, comment: "")
    }
}

struct RunDomWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RunDomWidget", provider: WeeklySummaryProvider()) { entry in
            RunDomWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("widget.displayName".widgetLocalized)
        .description("widget.description".widgetLocalized)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
