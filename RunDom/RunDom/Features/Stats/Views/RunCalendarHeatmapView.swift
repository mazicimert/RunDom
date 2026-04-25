import SwiftUI

struct RunCalendarHeatmapView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: CalendarHeatmapViewModel

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = LocalizationManager.shared.locale
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    private let cellSize: CGFloat = 20
    private let cellSpacing: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("stats.heatmap.title".localized)
                .font(.headline)

            HStack(alignment: .top, spacing: 8) {
                Color.clear
                    .frame(width: 26, height: 14)

                monthHeader
            }

            HStack(alignment: .top, spacing: 8) {
                weekdayLabels
                    .padding(.top, 1)

                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(weekStartDates, id: \.self) { weekStart in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { weekdayOffset in
                                CalendarHeatmapCell(
                                    day: day(for: weekStart, weekdayOffset: weekdayOffset),
                                    baseColor: resolvedBaseColor,
                                    size: cellSize,
                                    accessibilityText: accessibilityText(
                                        for: day(for: weekStart, weekdayOffset: weekdayOffset)
                                    ),
                                    onTap: { day in
                                        viewModel.selectDay(day)
                                    }
                                )
                            }
                        }
                    }
                }
            }

            legend

            if let selectedDay = viewModel.selectedDay {
                selectedDayDetail(for: selectedDay)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardStyle()
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.selectedDay != nil {
                viewModel.dismissSelection()
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.86), value: viewModel.selectedDay?.id)
    }

    private var resolvedBaseColor: Color {
        Color(hex: appState.currentUser?.color ?? "") ?? .accentColor
    }

    private var dayLookup: [Date: HeatmapDay] {
        Dictionary(uniqueKeysWithValues: viewModel.days.map { day in
            (calendar.startOfDay(for: day.date), day)
        })
    }

    private var weekStartDates: [Date] {
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return []
        }

        return (0..<12).compactMap { index in
            calendar.date(byAdding: .weekOfYear, value: index - 11, to: currentWeekStart)
        }
    }

    private var weekdayLabels: some View {
        VStack(alignment: .leading, spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { index in
                Text(weekdayText(for: index))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: cellSize, alignment: .leading)
            }
        }
    }

    private var monthHeader: some View {
        HStack(alignment: .top, spacing: cellSpacing) {
            ForEach(Array(weekStartDates.enumerated()), id: \.offset) { index, weekStart in
                Text(monthText(for: weekStart, at: index))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: cellSize, alignment: .leading)
            }
        }
        .frame(height: 14, alignment: .topLeading)
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("stats.heatmap.legend.low".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(0...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(legendColor(for: level))
                    .frame(width: cellSize, height: cellSize)
            }

            Text("stats.heatmap.legend.high".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func selectedDayDetail(for day: HeatmapDay) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.date.formatted(style: .long))
                    .font(.subheadline.weight(.semibold))

                Text(detailText(for: day))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.dismissSelection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func day(for weekStart: Date, weekdayOffset: Int) -> HeatmapDay? {
        guard let date = calendar.date(byAdding: .day, value: weekdayOffset, to: weekStart) else {
            return nil
        }
        return dayLookup[calendar.startOfDay(for: date)]
    }

    private func weekdayText(for index: Int) -> String {
        switch index {
        case 0:
            return "stats.heatmap.weekday.mon".localized
        case 2:
            return "stats.heatmap.weekday.wed".localized
        case 4:
            return "stats.heatmap.weekday.fri".localized
        default:
            return ""
        }
    }

    private func monthText(for weekStart: Date, at index: Int) -> String {
        if index == 0 {
            return formattedMonth(for: weekStart)
        }

        let previousWeekStart = weekStartDates[index - 1]
        let currentMonth = calendar.component(.month, from: weekStart)
        let previousMonth = calendar.component(.month, from: previousWeekStart)

        guard currentMonth != previousMonth else {
            return ""
        }

        return formattedMonth(for: weekStart)
    }

    private func formattedMonth(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }

    private func detailText(for day: HeatmapDay) -> String {
        guard day.distanceMeters > 0 else {
            return "stats.heatmap.noRun".localized
        }

        let distanceValue = UnitPreference.distanceValue(
            fromKilometers: day.distanceMeters / 1000.0,
            useMiles: UnitPreference.shared.useMiles
        )
        let distanceText = "\(distanceValue.formattedDecimal(maxFractionDigits: 1, minFractionDigits: 1)) \(UnitPreference.shared.distanceUnitLabel)"
        let runCountKey = day.runCount == 1 ? "stats.heatmap.runCount.single" : "stats.heatmap.runCount.multiple"

        return "\(distanceText) · \(runCountKey.localized(with: day.runCount))"
    }

    private func accessibilityText(for day: HeatmapDay?) -> String {
        guard let day else { return "" }
        return "accessibility.heatmap.day".localized(with: day.date.formatted(style: .long), detailText(for: day))
    }

    private func legendColor(for level: Int) -> Color {
        switch level {
        case 1:
            return resolvedBaseColor.opacity(0.25)
        case 2:
            return resolvedBaseColor.opacity(0.5)
        case 3:
            return resolvedBaseColor.opacity(0.75)
        case 4:
            return resolvedBaseColor
        default:
            return Color(uiColor: .tertiarySystemFill)
        }
    }
}
