import Combine
import Foundation

struct HeatmapDay: Identifiable, Equatable {
    let id: String
    let date: Date
    let distanceMeters: Double
    let runCount: Int
    let intensityLevel: Int
    let isToday: Bool
    let isInStreak: Bool
}

@MainActor
final class CalendarHeatmapViewModel: ObservableObject {
    @Published private(set) var days: [HeatmapDay] = []
    @Published var selectedDay: HeatmapDay?

    private let calendar: Calendar
    private let isoDateFormatter: DateFormatter

    init(calendar: Calendar = CalendarHeatmapViewModel.makeCalendar()) {
        self.calendar = calendar
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        self.isoDateFormatter = formatter
    }

    func buildHeatmap(from runs: [RunSession], streakDays: Set<Date>) {
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -83, to: today) else {
            days = []
            selectedDay = nil
            return
        }

        let groupedRuns = Dictionary(grouping: runs) { run in
            calendar.startOfDay(for: run.startDate)
        }
        let normalizedStreakDays = Self.normalizedStreakDays(
            streakDays.isEmpty ? Self.currentStreakDays(from: runs, calendar: calendar) : streakDays,
            calendar: calendar
        )

        days = (0..<84).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else {
                return nil
            }

            let dayRuns = groupedRuns[date] ?? []
            let distanceMeters = dayRuns.reduce(0) { partialResult, run in
                partialResult + run.distance
            }

            return HeatmapDay(
                id: isoDateFormatter.string(from: date),
                date: date,
                distanceMeters: distanceMeters,
                runCount: dayRuns.count,
                intensityLevel: intensityLevel(for: distanceMeters),
                isToday: calendar.isDate(date, inSameDayAs: today),
                isInStreak: normalizedStreakDays.contains(date)
            )
        }

        if let selectedDay {
            self.selectedDay = days.first(where: { $0.id == selectedDay.id })
        }
    }

    func selectDay(_ day: HeatmapDay) {
        selectedDay = day
    }

    func dismissSelection() {
        selectedDay = nil
    }

    nonisolated static func currentStreakDays(
        from runs: [RunSession],
        calendar: Calendar = makeCalendar()
    ) -> Set<Date> {
        let normalizedRunDays = Array(
            Set(runs.map { calendar.startOfDay(for: $0.startDate) })
        ).sorted(by: >)

        guard let latestRunDay = normalizedRunDays.first else { return [] }

        let today = calendar.startOfDay(for: Date())
        guard calendar.isDate(latestRunDay, inSameDayAs: today) || calendar.isDateInYesterday(latestRunDay) else {
            return []
        }

        var streakDays: Set<Date> = [latestRunDay]
        var expectedDay = latestRunDay

        while let previousDay = calendar.date(byAdding: .day, value: -1, to: expectedDay),
              normalizedRunDays.contains(previousDay) {
            streakDays.insert(previousDay)
            expectedDay = previousDay
        }

        return streakDays
    }

    private func intensityLevel(for distanceMeters: Double) -> Int {
        guard distanceMeters > 0 else { return 0 }

        let distanceValue = UnitPreference.distanceValue(
            fromKilometers: distanceMeters / 1000.0,
            useMiles: UnitPreference.shared.useMiles
        )
        let thresholds = UnitPreference.shared.useMiles ? [1.8, 3.7, 6.2] : [3.0, 6.0, 10.0]

        if distanceValue < thresholds[0] {
            return 1
        }
        if distanceValue < thresholds[1] {
            return 2
        }
        if distanceValue < thresholds[2] {
            return 3
        }
        return 4
    }

    private nonisolated static func normalizedStreakDays(_ streakDays: Set<Date>, calendar: Calendar) -> Set<Date> {
        Set(streakDays.map { calendar.startOfDay(for: $0) })
    }

    private nonisolated static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = LocalizationManager.shared.locale
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
}
