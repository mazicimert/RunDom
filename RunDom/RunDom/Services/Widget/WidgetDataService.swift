import Foundation
import WidgetKit

@MainActor
final class WidgetDataService {

    static let shared = WidgetDataService()

    private let defaults: UserDefaults?

    private init() {
        self.defaults = UserDefaults(suiteName: AppGroup.identifier)
    }

    func updateWeeklySummary(_ summary: WeeklySummary) {
        guard let defaults else {
            print("🟥 [WidgetDataService] App Group defaults nil — entitlement missing")
            return
        }

        do {
            let data = try JSONEncoder().encode(summary)
            defaults.set(data, forKey: AppGroup.weeklySummaryKey)
            let readback = defaults.data(forKey: AppGroup.weeklySummaryKey)
            print("🟩 [WidgetDataService] WROTE summary: trail=\(summary.totalTrail) runs=\(summary.runCount) bytes=\(data.count) readback=\(readback?.count ?? -1)")
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("🟥 [WidgetDataService] encode error: \(error.localizedDescription)")
        }
    }

    func updateHeatmap(_ data: HeatmapWidgetData) {
        guard let defaults else {
            print("🟥 [WidgetDataService] App Group defaults nil — entitlement missing")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(data)
            defaults.set(encoded, forKey: AppGroup.heatmapDataKey)
            print("🟩 [WidgetDataService] WROTE heatmap: cells=\(data.intensities.count) bytes=\(encoded.count)")
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("🟥 [WidgetDataService] heatmap encode error: \(error.localizedDescription)")
        }
    }

    func writeDiagnosticPing() {
        let ping = WeeklySummary(
            totalTrail: 9999,
            totalDistanceMeters: 12345,
            runCount: 7,
            streakDays: 5,
            userColorHex: "#FF6B6B"
        )
        updateWeeklySummary(ping)
    }

    func buildAndSaveSummary(from runs: [RunSession], currentUser: User?) {
        let weekStart = Self.startOfCurrentWeekUTC()
        let thisWeekRuns = runs.filter { $0.startDate >= weekStart }

        let totalTrail = thisWeekRuns.reduce(0.0) { $0 + $1.trail }
        let totalDistance = thisWeekRuns.reduce(0.0) { $0 + $1.distance }

        let userColorHex = currentUser?.color ?? WeeklySummary.empty.userColorHex

        let summary = WeeklySummary(
            totalTrail: Int(totalTrail.rounded()),
            totalDistanceMeters: totalDistance,
            runCount: thisWeekRuns.count,
            streakDays: currentUser?.streakDays ?? 0,
            userColorHex: userColorHex
        )

        updateWeeklySummary(summary)
        updateHeatmap(buildHeatmap(from: runs, userColorHex: userColorHex))
    }

    private func buildHeatmap(from runs: [RunSession], userColorHex: String) -> HeatmapWidgetData {
        let calendar = Self.heatmapCalendar
        let useMiles = UnitPreference.shared.useMiles

        let groupedDistances: [Date: Double] = runs.reduce(into: [:]) { partial, run in
            let day = calendar.startOfDay(for: run.startDate)
            partial[day, default: 0] += run.distance
        }

        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return HeatmapWidgetData(
                intensities: Array(repeating: 0, count: HeatmapWidgetData.dayCount),
                userColorHex: userColorHex
            )
        }

        var intensities: [Int] = []
        intensities.reserveCapacity(HeatmapWidgetData.dayCount)

        for weekOffset in 0..<12 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset - 11, to: currentWeekStart) else {
                intensities.append(contentsOf: Array(repeating: 0, count: 7))
                continue
            }

            for weekdayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: weekdayOffset, to: weekStart) else {
                    intensities.append(0)
                    continue
                }
                let day = calendar.startOfDay(for: date)
                let distanceMeters = groupedDistances[day] ?? 0
                intensities.append(Self.intensityLevel(forDistanceMeters: distanceMeters, useMiles: useMiles))
            }
        }

        return HeatmapWidgetData(intensities: intensities, userColorHex: userColorHex)
    }

    private static func intensityLevel(forDistanceMeters distanceMeters: Double, useMiles: Bool) -> Int {
        guard distanceMeters > 0 else { return 0 }

        let distanceValue = UnitPreference.distanceValue(
            fromKilometers: distanceMeters / 1000.0,
            useMiles: useMiles
        )
        let thresholds: [Double] = useMiles ? [1.8, 3.7, 6.2] : [3.0, 6.0, 10.0]

        if distanceValue < thresholds[0] { return 1 }
        if distanceValue < thresholds[1] { return 2 }
        if distanceValue < thresholds[2] { return 3 }
        return 4
    }

    private static let heatmapCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    private static func startOfCurrentWeekUTC() -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return calendar.date(from: components) ?? Date()
    }
}
