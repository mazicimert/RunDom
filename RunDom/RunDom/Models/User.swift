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
    /// Stable, normalized neighborhood key used for grouping. The localized
    /// `neighborhood` string remains display-only and supports legacy docs.
    var areaId: String?
    var dropzoneMultiplierExpiry: Date?
    var lastRunDate: Date?
    var fcmToken: String?
    var languageCode: String?
    var runnerProfile: RunnerProfile?
    var createdAt: Date = Date()

    // Operator-managed synthetic accounts. Optional fields keep existing user
    // documents backward compatible; nil is always treated as a real user.
    var isBot: Bool?
    var botProfileId: String?
    var botCity: String?
    var botCountryCode: String?
    var botVersion: Int?
    var botStatus: String?

    // Social (Phase 1) — optional until backfilled, treat nil as 0 / unset.
    var displayNameLowercased: String?
    var followersCount: Int?
    var followingCount: Int?
    var postsCount: Int?

    // Legal acceptance (Phase A.3) — set when the user explicitly accepts the
    // Community Guidelines + Terms of Use on first post. Bumping
    // `acceptedTermsVersion` past the bundled value re-triggers the gate.
    var acceptedCommunityGuidelinesAt: Date?
    var acceptedTermsVersion: Int?

    var hasActiveDropzoneBoost: Bool {
        guard let expiry = dropzoneMultiplierExpiry else { return false }
        return expiry > Date()
    }

    var isBotAccount: Bool { isBot == true }

    /// The streak as it stands *right now*, decayed for days elapsed since the
    /// last run. The stored `streakDays` is only recomputed when a run completes,
    /// so reading it directly shows a stale value after the user has been away.
    /// Use this for any *display* of the streak.
    var effectiveStreakDays: Int {
        StreakService.effectiveStreakDays(streakDays: streakDays, lastRunDate: lastRunDate)
    }

    var streakMultiplier: Double {
        let days = effectiveStreakDays
        if days >= AppConstants.Streak.tier3Days {
            return AppConstants.Streak.tier3Multiplier
        } else if days >= AppConstants.Streak.tier2Days {
            return AppConstants.Streak.tier2Multiplier
        } else if days >= AppConstants.Streak.tier1Days {
            return AppConstants.Streak.tier1Multiplier
        }
        return AppConstants.Streak.noStreakMultiplier
    }
}
