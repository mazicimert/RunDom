import Foundation

struct Season: Codable, Identifiable, Equatable {
    let id: String
    let startDate: Date
    let endDate: Date
    let weekNumber: Int
    let year: Int

    var isActive: Bool {
        let now = Date()
        return now >= startDate && now < endDate
    }

    var remainingTime: TimeInterval {
        max(endDate.timeIntervalSince(Date()), 0)
    }

    var progressPercentage: Double {
        let total = endDate.timeIntervalSince(startDate)
        let elapsed = Date().timeIntervalSince(startDate)
        guard total > 0 else { return 0 }
        return min(max(elapsed / total, 0), 1.0)
    }
}
