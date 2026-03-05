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

    var totalDistance: Double {
        filteredRuns.reduce(0) { $0 + $1.distance }
    }

    var totalTrail: Double {
        filteredRuns.reduce(0) { $0 + $1.trail }
    }

    var totalRunsCount: Int {
        filteredRuns.count
    }

    var totalTerritories: Int {
        filteredRuns.reduce(0) { $0 + $1.territoriesCaptured }
    }

    var chartData: [ChartDataPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRuns) { run -> Date in
            calendar.startOfDay(for: run.startDate)
        }

        let days: Int = period == .thisWeek ? 7 : 30
        let today = calendar.startOfDay(for: Date())

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayRuns = grouped[date] ?? []
            let trail = dayRuns.reduce(0) { $0 + $1.trail }
            return ChartDataPoint(date: date, value: trail)
        }.reversed()
    }

    private var filteredRuns: [RunSession] {
        let calendar = Calendar.current
        let now = Date()

        return runs.filter { run in
            switch period {
            case .thisWeek:
                return calendar.isDate(run.startDate, equalTo: now, toGranularity: .weekOfYear)
            case .thisMonth:
                return calendar.isDate(run.startDate, equalTo: now, toGranularity: .month)
            }
        }
    }

    // MARK: - Data Loading

    func loadStats(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await firestoreService.getRuns(userId: userId, limit: 100)
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
    let id = UUID()
    let date: Date
    let value: Double
}
