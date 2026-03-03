import Foundation

enum BadgeCategory: String, Codable, CaseIterable {
    case performance
    case territory
    case dropzone
    case exploration
    case streak
}

struct Badge: Codable, Identifiable, Equatable {
    let id: String
    let nameKey: String
    let descriptionKey: String
    let iconName: String
    let category: BadgeCategory
    let isSecret: Bool
    var isUnlocked: Bool = false
    var unlockedAt: Date?
    var progress: Double = 0
    var targetValue: Double = 1

    var localizedName: String {
        nameKey.localized
    }

    var localizedDescription: String {
        descriptionKey.localized
    }

    var progressPercentage: Double {
        guard targetValue > 0 else { return 0 }
        return min(progress / targetValue, 1.0)
    }
}
