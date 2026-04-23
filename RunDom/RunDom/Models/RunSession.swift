import Foundation

enum RunMode: String, Codable, CaseIterable {
    case normal
    case boost
}

struct RunSession: Codable, Identifiable, Equatable, Hashable {
    static func == (lhs: RunSession, rhs: RunSession) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: String
    let userId: String
    let mode: RunMode
    let startDate: Date
    var endDate: Date?
    var distance: Double = 0
    var avgSpeed: Double = 0
    var maxSpeed: Double = 0
    var trail: Double = 0
    var territoriesCaptured: Int = 0
    var uniqueZonesVisited: Int = 0
    var totalZonesVisited: Int = 0
    var route: [RoutePoint] = []
    var isBoostActive: Bool = true
    var seasonId: String?
    var rating: Int?
    var tags: [String] = []
    var note: String?

    var duration: TimeInterval {
        let end = endDate ?? Date()
        return end.timeIntervalSince(startDate)
    }

    var durationMinutes: Double {
        duration / 60.0
    }

    var uniqueZoneRatio: Double {
        guard totalZonesVisited > 0 else { return 1.0 }
        return Double(uniqueZonesVisited) / Double(totalZonesVisited)
    }
}
