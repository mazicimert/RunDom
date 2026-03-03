import Foundation

struct Territory: Codable, Identifiable, Equatable {
    var id: String { h3Index }
    let h3Index: String
    var ownerId: String
    var ownerColor: String
    var defenseLevel: Double
    var lastRunDate: Date
    var totalDistance: Double = 0

    var isDecaying: Bool {
        let hoursSinceLastRun = Date().timeIntervalSince(lastRunDate) / 3600
        return hoursSinceLastRun >= Double(AppConstants.Game.defenseDecayHours)
    }

    var decayedDefenseLevel: Double {
        let hoursSinceLastRun = Date().timeIntervalSince(lastRunDate) / 3600
        let decayHours = hoursSinceLastRun - Double(AppConstants.Game.defenseDecayHours)
        guard decayHours > 0 else { return defenseLevel }
        let decayFactor = max(0, 1.0 - (decayHours / 168.0))
        return defenseLevel * decayFactor
    }
}
