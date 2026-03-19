import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String
    var displayName: String
    var email: String
    var photoURL: String?
    var color: String
    var isPremium: Bool = true
    var streakDays: Int = 0
    var totalTrail: Double = 0
    var totalDistance: Double = 0
    var totalRuns: Int = 0
    var currentSeasonTrail: Double = 0
    var currentSeasonId: String?
    var neighborhood: String?
    var dropzoneMultiplierExpiry: Date?
    var lastRunDate: Date?
    var fcmToken: String?
    var languageCode: String?
    var createdAt: Date = Date()

    var hasActiveDropzoneBoost: Bool {
        guard let expiry = dropzoneMultiplierExpiry else { return false }
        return expiry > Date()
    }

    var streakMultiplier: Double {
        if streakDays >= AppConstants.Streak.tier3Days {
            return AppConstants.Streak.tier3Multiplier
        } else if streakDays >= AppConstants.Streak.tier2Days {
            return AppConstants.Streak.tier2Multiplier
        } else if streakDays >= AppConstants.Streak.tier1Days {
            return AppConstants.Streak.tier1Multiplier
        }
        return AppConstants.Streak.noStreakMultiplier
    }
}
