import Foundation

/// Manages running streak tracking with tier-based multipliers.
///
/// Streak tiers:
/// - 3 days → x1.2
/// - 7 days → x1.5
/// - 14 days → x2.0
///
/// Missing 1 day drops one tier (does NOT reset to zero).
final class StreakService {

    // MARK: - Streak Tier

    enum StreakTier: Int, CaseIterable, Comparable {
        case none = 0
        case tier1 = 1
        case tier2 = 2
        case tier3 = 3

        var multiplier: Double {
            switch self {
            case .none: return AppConstants.Streak.noStreakMultiplier
            case .tier1: return AppConstants.Streak.tier1Multiplier
            case .tier2: return AppConstants.Streak.tier2Multiplier
            case .tier3: return AppConstants.Streak.tier3Multiplier
            }
        }

        var requiredDays: Int {
            switch self {
            case .none: return 0
            case .tier1: return AppConstants.Streak.tier1Days
            case .tier2: return AppConstants.Streak.tier2Days
            case .tier3: return AppConstants.Streak.tier3Days
            }
        }

        var nextTier: StreakTier? {
            switch self {
            case .none: return .tier1
            case .tier1: return .tier2
            case .tier2: return .tier3
            case .tier3: return nil
            }
        }

        var previousTier: StreakTier {
            switch self {
            case .none: return .none
            case .tier1: return .none
            case .tier2: return .tier1
            case .tier3: return .tier2
            }
        }

        static func < (lhs: StreakTier, rhs: StreakTier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Streak Info

    struct StreakInfo {
        let days: Int
        let tier: StreakTier
        let multiplier: Double
        let daysUntilNextTier: Int?
        let isAtRisk: Bool
    }

    // MARK: - Services

    private let firestoreService: FirestoreService

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
    }

    // MARK: - Tier Calculation

    func currentTier(streakDays: Int) -> StreakTier {
        if streakDays >= AppConstants.Streak.tier3Days {
            return .tier3
        } else if streakDays >= AppConstants.Streak.tier2Days {
            return .tier2
        } else if streakDays >= AppConstants.Streak.tier1Days {
            return .tier1
        }
        return .none
    }

    func streakInfo(streakDays: Int, lastRunDate: Date?) -> StreakInfo {
        let tier = currentTier(streakDays: streakDays)

        let daysUntilNext: Int?
        if let nextTier = tier.nextTier {
            daysUntilNext = nextTier.requiredDays - streakDays
        } else {
            daysUntilNext = nil
        }

        let isAtRisk = checkStreakAtRisk(lastRunDate: lastRunDate)

        return StreakInfo(
            days: streakDays,
            tier: tier,
            multiplier: tier.multiplier,
            daysUntilNextTier: daysUntilNext,
            isAtRisk: isAtRisk
        )
    }

    // MARK: - Streak Update After Run

    /// Updates streak after completing a run. Returns the new streak day count.
    func updateStreak(currentStreakDays: Int, lastRunDate: Date?) -> Int {
        guard let lastRun = lastRunDate else {
            // First run ever
            return 1
        }

        let calendar = Calendar.current

        if calendar.isDateInToday(lastRun) {
            // Already ran today — no change
            return currentStreakDays
        }

        if calendar.isDateInYesterday(lastRun) {
            // Consecutive day — increment
            return currentStreakDays + 1
        }

        // Missed more than 1 day — drop one tier (not full reset)
        let daysSinceLastRun = calendar.dateComponents([.day], from: lastRun, to: Date()).day ?? 0

        if daysSinceLastRun == 2 {
            // Missed exactly 1 day — drop one tier
            let currentTier = currentTier(streakDays: currentStreakDays)
            let droppedTier = currentTier.previousTier
            return max(droppedTier.requiredDays, 1)
        }

        // Missed 2+ days — reset to 1
        return 1
    }

    // MARK: - Risk Check

    /// Returns true if the user hasn't run today and their streak is at risk.
    func checkStreakAtRisk(lastRunDate: Date?) -> Bool {
        guard let lastRun = lastRunDate else { return false }
        let calendar = Calendar.current
        // At risk if last run was yesterday (they need to run today)
        return calendar.isDateInYesterday(lastRun)
    }

    /// Returns true if the streak should trigger a warning notification.
    func shouldSendStreakWarning(lastRunDate: Date?, streakDays: Int) -> Bool {
        guard streakDays >= AppConstants.Streak.tier1Days else { return false }
        return checkStreakAtRisk(lastRunDate: lastRunDate)
    }

    // MARK: - Persistence

    func saveStreakUpdate(userId: String, newStreakDays: Int) async throws {
        var user = try await firestoreService.getUser(id: userId)
        user?.streakDays = newStreakDays
        if let updatedUser = user {
            try await firestoreService.updateUser(updatedUser)
        }
        AppLogger.game.info("Streak updated for \(userId): \(newStreakDays) days")
    }
}
