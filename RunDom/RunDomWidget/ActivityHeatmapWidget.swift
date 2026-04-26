import WidgetKit
import SwiftUI

struct HeatmapEntry: TimelineEntry {
    let date: Date
    let data: HeatmapWidgetData
}

struct HeatmapProvider: TimelineProvider {
    func placeholder(in context: Context) -> HeatmapEntry {
        HeatmapEntry(date: Date(), data: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (HeatmapEntry) -> Void) {
        completion(HeatmapEntry(date: Date(), data: loadData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HeatmapEntry>) -> Void) {
        let now = Date()
        let entry = HeatmapEntry(date: now, data: loadData())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadData() -> HeatmapWidgetData {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier) else {
            print("🟥 [HeatmapWidget] suiteName failed — App Group entitlement missing on widget")
            return .empty
        }
        guard let bytes = defaults.data(forKey: AppGroup.heatmapDataKey) else {
            print("🟧 [HeatmapWidget] no heatmap data yet")
            return .empty
        }
        guard let decoded = try? JSONDecoder().decode(HeatmapWidgetData.self, from: bytes) else {
            print("🟥 [HeatmapWidget] decode failed")
            return .empty
        }
        return decoded
    }
}

struct ActivityHeatmapWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HeatmapEntry

    var body: some View {
        switch family {
        case .systemSmall:
            HeatmapGridView(intensities: lastWeeks(7), columns: 7, baseColor: baseColor)
                .containerBackground(Color.black, for: .widget)
                .widgetURL(URL(string: "rundom://stats"))
        default:
            HeatmapGridView(intensities: entry.data.intensities, columns: 12, baseColor: baseColor)
                .containerBackground(Color.black, for: .widget)
                .widgetURL(URL(string: "rundom://stats"))
        }
    }

    private var baseColor: Color {
        Color(hex: entry.data.userColorHex) ?? Color(hex: HeatmapWidgetData.empty.userColorHex) ?? .accentColor
    }

    private func lastWeeks(_ weekCount: Int) -> [Int] {
        let cellCount = weekCount * 7
        guard entry.data.intensities.count >= cellCount else {
            return entry.data.intensities
        }
        return Array(entry.data.intensities.suffix(cellCount))
    }
}

private struct HeatmapGridView: View {
    let intensities: [Int]
    let columns: Int
    let baseColor: Color

    private let spacing: CGFloat = 3
    private let cornerRadius: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let cellSize = max(
                0,
                min(
                    (proxy.size.width - CGFloat(columns - 1) * spacing) / CGFloat(columns),
                    (proxy.size.height - CGFloat(7 - 1) * spacing) / 7
                )
            )

            let gridWidth = CGFloat(columns) * cellSize + CGFloat(columns - 1) * spacing
            let gridHeight = CGFloat(7) * cellSize + CGFloat(6) * spacing

            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<columns, id: \.self) { columnIndex in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { rowIndex in
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(fillColor(for: intensity(at: columnIndex, row: rowIndex)))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
            .frame(width: gridWidth, height: gridHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func intensity(at column: Int, row: Int) -> Int {
        let index = column * 7 + row
        guard intensities.indices.contains(index) else { return 0 }
        return intensities[index]
    }

    private func fillColor(for level: Int) -> Color {
        switch level {
        case 1: return baseColor.opacity(0.25)
        case 2: return baseColor.opacity(0.5)
        case 3: return baseColor.opacity(0.75)
        case 4: return baseColor
        default: return Color.white.opacity(0.08)
        }
    }
}

private extension String {
    var heatmapWidgetLocalized: String {
        NSLocalizedString(self, comment: "")
    }
}

struct ActivityHeatmapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ActivityHeatmapWidget", provider: HeatmapProvider()) { entry in
            ActivityHeatmapWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("widget.heatmap.displayName".heatmapWidgetLocalized)
        .description("widget.heatmap.description".heatmapWidgetLocalized)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
