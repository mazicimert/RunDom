import Foundation

struct WeeklySummary: Codable, Equatable {
    var totalTrail: Int
    var totalDistanceMeters: Double
    var runCount: Int
    var streakDays: Int
    var userColorHex: String

    static let empty = WeeklySummary(
        totalTrail: 0,
        totalDistanceMeters: 0,
        runCount: 0,
        streakDays: 0,
        userColorHex: "#4ECDC4"
    )
}
