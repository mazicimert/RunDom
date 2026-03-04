import Foundation

/// Manages weekly seasons: creation, active season lookup, and reset logic.
/// Seasons reset every Monday 00:00 UTC.
final class SeasonService {

    // MARK: - Services

    private let firestoreService: FirestoreService

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
    }

    // MARK: - Active Season

    /// Returns the current active season from Firestore, or creates one if none exists.
    func getOrCreateCurrentSeason() async throws -> Season {
        if let season = try await firestoreService.getCurrentSeason() {
            return season
        }
        let season = generateCurrentSeason()
        AppLogger.game.info("No active season found, using generated: \(season.id)")
        return season
    }

    // MARK: - Season Generation

    /// Generates a Season for the current week based on UTC calendar.
    func generateCurrentSeason() -> Season {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let now = Date()
        let weekday = calendar.component(.weekday, from: now)

        // ISO 8601: Monday = 2. Calculate days since Monday.
        let daysSinceMonday = (weekday + 5) % 7
        let startOfWeek = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysSinceMonday, to: now)!)
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!

        let weekNumber = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.yearForWeekOfYear, from: now)

        return Season(
            id: "season_\(year)_w\(weekNumber)",
            startDate: startOfWeek,
            endDate: endOfWeek,
            weekNumber: weekNumber,
            year: year
        )
    }

    /// Generates the next season (following week).
    func generateNextSeason() -> Season {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let nextWeekDate = calendar.date(byAdding: .weekOfYear, value: 1, to: Date())!
        let weekday = calendar.component(.weekday, from: nextWeekDate)
        let daysSinceMonday = (weekday + 5) % 7
        let startOfWeek = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysSinceMonday, to: nextWeekDate)!)
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!

        let weekNumber = calendar.component(.weekOfYear, from: nextWeekDate)
        let year = calendar.component(.yearForWeekOfYear, from: nextWeekDate)

        return Season(
            id: "season_\(year)_w\(weekNumber)",
            startDate: startOfWeek,
            endDate: endOfWeek,
            weekNumber: weekNumber,
            year: year
        )
    }

    // MARK: - Season Status

    /// Time remaining in the current season.
    func timeRemainingInSeason() -> TimeInterval {
        let current = generateCurrentSeason()
        return max(current.endDate.timeIntervalSince(Date()), 0)
    }

    /// Progress percentage through the current season (0.0 to 1.0).
    func seasonProgress() -> Double {
        let current = generateCurrentSeason()
        return current.progressPercentage
    }

    /// Returns true if a season reset should happen (called at app launch or foreground).
    func shouldResetSeason(lastKnownSeasonId: String?) -> Bool {
        let current = generateCurrentSeason()
        return lastKnownSeasonId != current.id
    }
}
