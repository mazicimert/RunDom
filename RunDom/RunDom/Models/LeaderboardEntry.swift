import Foundation

enum LeaderboardScope: String, Codable, CaseIterable {
    case global
    case neighborhood
}

enum LeaderboardPeriod: String, Codable, CaseIterable {
    case weekly
    case allTime
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
    let areaId: String?
    let seasonId: String
    let territoriesOwned: Int

    init(
        id: String,
        userId: String,
        displayName: String,
        photoURL: String?,
        color: String,
        trail: Double,
        rank: Int,
        neighborhood: String?,
        areaId: String? = nil,
        seasonId: String,
        territoriesOwned: Int
    ) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.photoURL = photoURL
        self.color = color
        self.trail = trail
        self.rank = rank
        self.neighborhood = neighborhood
        self.areaId = areaId
        self.seasonId = seasonId
        self.territoriesOwned = territoriesOwned
    }

    func withTerritoriesOwned(_ count: Int) -> LeaderboardEntry {
        LeaderboardEntry(
            id: id,
            userId: userId,
            displayName: displayName,
            photoURL: photoURL,
            color: color,
            trail: trail,
            rank: rank,
            neighborhood: neighborhood,
            areaId: areaId,
            seasonId: seasonId,
            territoriesOwned: count
        )
    }
}
