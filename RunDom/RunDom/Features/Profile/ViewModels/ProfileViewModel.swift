import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Published State

    @Published var user: User?
    @Published var badges: [Badge] = []
    @Published var latestRun: RunSession?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Services

    private let firestoreService: FirestoreService
    private let storageService: StorageService
    private let badgeService: BadgeService

    // MARK: - Init

    init(firestoreService: FirestoreService = FirestoreService(),
         storageService: StorageService = StorageService(),
         badgeService: BadgeService = BadgeService()) {
        self.firestoreService = firestoreService
        self.storageService = storageService
        self.badgeService = badgeService
    }

    // MARK: - Computed

    var unlockedBadges: [Badge] {
        badges.filter { $0.isUnlocked }
    }

    var lockedBadges: [Badge] {
        badges.filter { !$0.isUnlocked && !$0.isSecret }
    }

    var streakText: String {
        guard let user else { return "" }
        return String(format: "profile.streakDays".localized, user.streakDays)
    }

    // MARK: - Data Loading

    func loadProfile(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await badgeService.syncAndEvaluateBadges(userId: userId)

            async let userTask = firestoreService.getUser(id: userId)
            async let badgesTask = firestoreService.getBadges(userId: userId)
            async let latestRunTask = firestoreService.getRuns(userId: userId, limit: 1)

            let (fetchedUser, fetchedBadges, fetchedLatestRunResult) = try await (userTask, badgesTask, latestRunTask)
            user = fetchedUser
            badges = sortBadges(fetchedBadges)
            latestRun = fetchedLatestRunResult.runs.first
        } catch {
            AppLogger.firebase.error("Failed to load profile: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }

        isLoading = false
    }

    func refreshUser(userId: String) async {
        do {
            user = try await firestoreService.getUser(id: userId)
        } catch {
            AppLogger.firebase.error("Failed to refresh user: \(error.localizedDescription)")
        }
    }

    private func sortBadges(_ badges: [Badge]) -> [Badge] {
        let displayOrder: [String] = [
            "boost_5",
            "distance_10k",
            "distance_5k",
            "dropzone_5",
            "first_dropzone",
            "first_run",
            "first_territory",
            "streak_30",
            "streak_7",
            "territory_100",
            "territory_25",
            "total_distance_100k"
        ]
        let indexById = Dictionary(uniqueKeysWithValues: displayOrder.enumerated().map { ($1, $0) })

        return badges.sorted { lhs, rhs in
            let lhsIndex = indexById[lhs.id] ?? Int.max
            let rhsIndex = indexById[rhs.id] ?? Int.max

            if lhsIndex == rhsIndex {
                return lhs.localizedName < rhs.localizedName
            }
            return lhsIndex < rhsIndex
        }
    }
}
