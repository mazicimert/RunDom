import SwiftUI

enum StatsPeriod: String, CaseIterable {
    case thisWeek
    case thisMonth

    var localized: String {
        switch self {
        case .thisWeek: return "stats.thisWeek".localized
        case .thisMonth: return "stats.thisMonth".localized
        }
    }
}

enum StatsDeltaTone {
    case positive
    case negative
    case neutral
    case unavailable

    var color: Color {
        switch self {
        case .positive:
            return .green
        case .negative:
            return .red
        case .neutral:
            return .secondary
        case .unavailable:
            return .secondary
        }
    }
}

struct StatsDeltaSummary {
    let text: String
    let tone: StatsDeltaTone
}

@MainActor
final class StatsViewModel: ObservableObject {

    // MARK: - Published State

    @Published var period: StatsPeriod = .thisWeek
    @Published var runs: [RunSession] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Services

    private let firestoreService: FirestoreService

    // MARK: - Init

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
    }

    // MARK: - Computed

    var totalDistanceMeters: Double {
        filteredRuns.reduce(0) { $0 + $1.distance }
    }

    var totalDistanceKm: Double {
        totalDistanceMeters / 1000.0
    }

    var totalDistanceText: String {
        totalDistanceMeters.formattedDistanceFromMeters
    }

    var totalDistanceCompactText: String {
        "\(totalDistanceKm.formattedDecimal(maxFractionDigits: 1, minFractionDigits: 1)) km"
    }

    var totalTrail: Double {
        filteredRuns.reduce(0) { $0 + $1.trail }
    }

    var heroTrailText: String {
        totalTrail.formattedTrail
    }

    var totalRunsCount: Int {
        filteredRuns.count
    }

    var runCountSummaryText: String {
        if totalRunsCount == 1 {
            return "stats.runCount.single".localized(with: totalRunsCount)
        }
        return "stats.runCount.multiple".localized(with: totalRunsCount)
    }

    var totalTerritories: Int {
        // Distinct territories visited in the selected period.
        // Prefer route-based H3 cells for true uniqueness across all runs.
        let uniqueVisitedCells = Set(
            filteredRuns.flatMap { run in
                run.route.map { point in
                    point.coordinate.h3Index(resolution: AppConstants.Location.h3Resolution)
                }
            }
        )

        if !uniqueVisitedCells.isEmpty {
            return uniqueVisitedCells.count
        }

        // Fallback for legacy runs that may not contain route points.
        return filteredRuns.reduce(0) { $0 + $1.uniqueZonesVisited }
    }

    var chartData: [ChartDataPoint] {
        buildChartData { $0.trail }
    }

    var distanceChartData: [ChartDataPoint] {
        buildChartData { $0.distance / 1000.0 }
    }

    var previousPeriodTrailTotal: Double {
        previousPeriodRuns.reduce(0) { $0 + $1.trail }
    }

    var previousPeriodDistanceTotal: Double {
        previousPeriodRuns.reduce(0) { $0 + $1.distance }
    }

    var periodSummaryText: String {
        "stats.periodSummary".localized(
            with: runCountSummaryText,
            totalDistanceText,
            totalTrail.formattedTrail
        )
    }

    var trailDeltaSummary: StatsDeltaSummary {
        buildDeltaSummary(current: totalTrail, previous: previousPeriodTrailTotal, hasPreviousData: !previousPeriodRuns.isEmpty)
    }

    var distanceDeltaSummary: StatsDeltaSummary {
        buildDeltaSummary(
            current: totalDistanceKm,
            previous: previousPeriodDistanceTotal / 1000.0,
            hasPreviousData: !previousPeriodRuns.isEmpty
        )
    }

    var trailDeltaText: String {
        trailDeltaSummary.text
    }

    var distanceDeltaText: String {
        distanceDeltaSummary.text
    }

    private func buildChartData(valueFor: (RunSession) -> Double) -> [ChartDataPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRuns) { run -> Date in
            calendar.startOfDay(for: run.startDate)
        }

        let days: Int = period == .thisWeek ? 7 : 30
        let today = calendar.startOfDay(for: Date())

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayRuns = grouped[date] ?? []
            let value = dayRuns.reduce(0) { $0 + valueFor($1) }
            return ChartDataPoint(date: date, value: value)
        }.reversed()
    }

    private var currentPeriodInterval: DateInterval? {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .thisWeek:
            return calendar.dateInterval(of: .weekOfYear, for: now)
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now)
        }
    }

    private var previousPeriodInterval: DateInterval? {
        let calendar = Calendar.current

        guard let currentPeriodInterval else { return nil }

        switch period {
        case .thisWeek:
            guard let previousDate = calendar.date(byAdding: .weekOfYear, value: -1, to: currentPeriodInterval.start) else {
                return nil
            }
            return calendar.dateInterval(of: .weekOfYear, for: previousDate)
        case .thisMonth:
            guard let previousDate = calendar.date(byAdding: .month, value: -1, to: currentPeriodInterval.start) else {
                return nil
            }
            return calendar.dateInterval(of: .month, for: previousDate)
        }
    }

    private var filteredRuns: [RunSession] {
        guard let currentPeriodInterval else { return [] }
        return runs.filter { currentPeriodInterval.contains($0.startDate) }
    }

    private var previousPeriodRuns: [RunSession] {
        guard let previousPeriodInterval else { return [] }
        return runs.filter { previousPeriodInterval.contains($0.startDate) }
    }

    private func buildDeltaSummary(current: Double, previous: Double, hasPreviousData: Bool) -> StatsDeltaSummary {
        guard hasPreviousData else {
            return StatsDeltaSummary(
                text: "stats.delta.noComparison".localized,
                tone: .unavailable
            )
        }

        if previous == 0 {
            if current == 0 {
                return StatsDeltaSummary(
                    text: "stats.delta.noComparison".localized,
                    tone: .neutral
                )
            }
            return StatsDeltaSummary(
                text: "stats.delta.newActivity".localized,
                tone: .positive
            )
        }

        let deltaPercent = ((current - previous) / previous) * 100

        let deltaTextKey = period == .thisWeek ? "stats.delta.previousWeek" : "stats.delta.previousMonth"
        let tone: StatsDeltaTone
        if deltaPercent > 0 {
            tone = .positive
        } else if deltaPercent < 0 {
            tone = .negative
        } else {
            tone = .neutral
        }

        return StatsDeltaSummary(
            text: deltaTextKey.localized(with: deltaPercent.formattedPercentChange),
            tone: tone
        )
    }

    // MARK: - Data Loading

    func loadStats(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch enough runs to cover the current + previous period for delta comparison.
            // Monthly view needs ~60 days of data; at ~3 runs/day that's ~180 runs.
            let result = try await firestoreService.getRuns(userId: userId, limit: 200)
            runs = result.runs
        } catch {
            AppLogger.firebase.error("Failed to load stats: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }

        isLoading = false
    }
}

// MARK: - Chart Data Point

struct ChartDataPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
}
