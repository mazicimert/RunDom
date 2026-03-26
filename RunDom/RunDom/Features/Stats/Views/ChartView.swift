import Charts
import SwiftUI

enum StatsChartStyle {
    case bar
    case lineArea
}

struct TrailChartView: View {
    let title: String
    let data: [ChartDataPoint]
    var style: StatsChartStyle = .bar
    var accentColor: Color = .accentColor
    var insightText: String
    var insightColor: Color = .secondary
    var valueFormatter: (Double) -> String
    var axisValueFormatter: ((Double) -> String)?
    @Binding var selectedPoint: ChartDataPoint?

    private var isMonthly: Bool { data.count > 7 }

    init(
        title: String,
        data: [ChartDataPoint],
        style: StatsChartStyle = .bar,
        accentColor: Color = .accentColor,
        insightText: String,
        insightColor: Color = .secondary,
        valueFormatter: @escaping (Double) -> String = { $0.formattedTrail },
        axisValueFormatter: ((Double) -> String)? = nil,
        selectedPoint: Binding<ChartDataPoint?> = .constant(nil)
    ) {
        self.title = title
        self.data = data
        self.style = style
        self.accentColor = accentColor
        self.insightText = insightText
        self.insightColor = insightColor
        self.valueFormatter = valueFormatter
        self.axisValueFormatter = axisValueFormatter
        self._selectedPoint = selectedPoint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            chartHeader

            if data.isEmpty {
                emptyState
            } else {
                chart
            }
        }
        .padding(AppConstants.UI.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }

    private var chartHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))

                Text(insightText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(insightColor)
            }

            Spacer(minLength: 0)

            if let selectedPoint {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(valueFormatter(selectedPoint.value))
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(.primary)

                    Text(selectionDateText(for: selectedPoint.date))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
            }
        }
    }

    private var emptyState: some View {
        Text("stats.noData".localized)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 168)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.02))
            )
    }

    private var chart: some View {
        Chart(data) { point in
            switch style {
            case .bar:
                BarMark(
                    x: .value("stats.date".localized, point.date, unit: .day),
                    y: .value(title, point.value)
                )
                .foregroundStyle(barFill(for: point))
                .cornerRadius(5)

            case .lineArea:
                AreaMark(
                    x: .value("stats.date".localized, point.date, unit: .day),
                    y: .value(title, point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor.opacity(0.28), accentColor.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("stats.date".localized, point.date, unit: .day),
                    y: .value(title, point.value)
                )
                .foregroundStyle(accentColor)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }

            if let selectedPoint, selectedPoint.date == point.date {
                PointMark(
                    x: .value("stats.date".localized, point.date, unit: .day),
                    y: .value(title, point.value)
                )
                .foregroundStyle(accentColor)
                .symbolSize(style == .lineArea ? 70 : 54)
            }
        }
        .chartXAxis {
            if isMonthly {
                AxisMarks(values: .stride(by: .day, count: 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.day().month(.defaultDigits))
                                .font(.caption2)
                        }
                    }
                }
            } else {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.weekday(.abbreviated))
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.primary.opacity(0.08))
                AxisValueLabel {
                        if let val = value.as(Double.self) {
                        Text((axisValueFormatter ?? valueFormatter)(val))
                            .font(.caption2)
                        }
                    }
                }
            }
        .chartYScale(domain: .automatic(includesZero: true))
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateSelection(at: value.location, proxy: proxy, geometry: geometry)
                            }
                    )
            }
        }
        .frame(height: 188)
    }

    private func barFill(for point: ChartDataPoint) -> AnyShapeStyle {
        if let selectedPoint {
            if selectedPoint.date == point.date {
                return AnyShapeStyle(accentColor.gradient)
            }

            return AnyShapeStyle(accentColor.opacity(0.38))
        }

        return AnyShapeStyle(accentColor.gradient)
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let plotArea = geometry[plotFrame]
        let relativeX = location.x - plotArea.origin.x

        guard relativeX >= 0, relativeX <= plotArea.width else { return }
        guard let selectedDate = proxy.value(atX: relativeX, as: Date.self) else { return }

        let newPoint = nearestPoint(to: selectedDate)
        if newPoint?.date != selectedPoint?.date {
            Haptics.impact(.light)
        }
        selectedPoint = newPoint
    }

    private func nearestPoint(to date: Date) -> ChartDataPoint? {
        data.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    private func selectionDateText(for date: Date) -> String {
        "\(date.formattedHistoryWeekday()) \(date.formattedHistoryDayMonth())"
    }
}

#Preview {
    VStack(spacing: 16) {
        TrailChartView(
            title: "stats.trailChart".localized,
            data: [
                ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -6, to: Date())!, value: 250),
                ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, value: 480),
                ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!, value: 0),
                ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, value: 720),
                ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, value: 350),
                ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, value: 900),
                ChartDataPoint(date: Date(), value: 150),
            ],
            style: .bar,
            accentColor: .orange,
            insightText: "+18% vs last week"
        )

        TrailChartView(
            title: "stats.distanceChart".localized,
            data: [
                ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -6, to: Date())!, value: 1.4),
                ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, value: 0.8),
                ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!, value: 0),
                ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, value: 2.1),
                ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, value: 1.1),
                ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, value: 3.2),
                ChartDataPoint(date: Date(), value: 0.6),
            ],
            style: .lineArea,
            accentColor: .green,
            insightText: "+12% vs last week",
            valueFormatter: { "\($0.formattedDecimal(maxFractionDigits: 1, minFractionDigits: 1)) km" }
        )
    }
    .padding()
    .background(Color.surfacePrimary)
}
