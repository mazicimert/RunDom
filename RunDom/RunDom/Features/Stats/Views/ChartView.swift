import SwiftUI
import Charts

struct TrailChartView: View {
    let data: [ChartDataPoint]
    var barColor: Color = .accentColor

    var body: some View {
        if data.isEmpty {
            Text("stats.noData".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 180)
        } else {
            Chart(data) { point in
                BarMark(
                    x: .value("stats.date".localized, point.date, unit: .day),
                    y: .value("trail.unit".localized, point.value)
                )
                .foregroundStyle(barColor.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.weekday(.abbreviated))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text(val.formattedTrail)
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }
}

#Preview {
    TrailChartView(data: [
        ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -6, to: Date())!, value: 250),
        ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, value: 480),
        ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!, value: 0),
        ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, value: 720),
        ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, value: 350),
        ChartDataPoint(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, value: 900),
        ChartDataPoint(date: Date(), value: 150),
    ])
    .padding()
}
