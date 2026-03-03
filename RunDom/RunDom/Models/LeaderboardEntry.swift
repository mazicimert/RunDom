import Foundation

enum LeaderboardScope: String, Codable, CaseIterable {
    case global
    case neighborhood
}

struct LeaderboardEntry: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let displayName: String
    let photoURL: String?
    let color: String
    let trail: Double
    let rank: Int
    let neighborhood: String?
    let seasonId: String
    let territoriesOwned: Int
}
