import Foundation

struct WeeklyReport: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let seasonId: String
    let weekNumber: Int
    let year: Int
    let totalDistance: Double
    let totalTrail: Double
    let totalRuns: Int
    let territoriesGained: Int
    let territoriesLost: Int
    let avgSpeed: Double
    let longestRun: Double
    let previousWeekTrail: Double
    let globalRank: Int?
    let neighborhoodRank: Int?
    let createdAt: Date

    var weekOverWeekChange: Double {
        guard previousWeekTrail > 0 else { return 0 }
        return ((totalTrail - previousWeekTrail) / previousWeekTrail) * 100
    }

    var netTerritories: Int {
        territoriesGained - territoriesLost
    }
}
