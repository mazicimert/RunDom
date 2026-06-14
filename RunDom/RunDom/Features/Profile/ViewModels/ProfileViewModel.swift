import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Published State

    @Published var user: User?
    @Published var badges: [Badge] = []
    @Published var latestRun: RunSession?
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Services

    private let firestoreService: FirestoreService
    private let storageService: StorageService
    private let badgeService: BadgeService
    private let postService: PostService

    // MARK: - Init

    init(firestoreService: FirestoreService = FirestoreService(),
         storageService: StorageService = StorageService(),
         badgeService: BadgeService = BadgeService(),
         postService: PostService = PostService()) {
        self.firestoreService = firestoreService
        self.storageService = storageService
        self.badgeService = badgeService
        self.postService = postService
    }

    // MARK: - Computed

    var unlockedBadges: [Badge] {
        badges.filter { $0.isUnlocked }
    }

    var lockedBadges: [Badge] {
        badges.filter { !$0.isUnlocked && !$0.isSecret }
    }

    /// The most meaningful badges to surface in the profile preview: unlocked
    /// first (keeping their display order), then locked badges closest to
    /// completion, then any remaining (incl. secret) ones.
    var previewBadges: [Badge] {
        let unlocked = badges.filter { $0.isUnlocked }
        let inProgress = badges
            .filter { !$0.isUnlocked && !$0.isSecret }
            .sorted { $0.progressPercentage > $1.progressPercentage }
        let remaining = badges.filter { !$0.isUnlocked && $0.isSecret }
        return Array((unlocked + inProgress + remaining).prefix(Self.badgePreviewCount))
    }

    static let badgePreviewCount = 6

    var streakText: String {
        guard let user else { return "" }
        return String(format: "profile.streakDays".localized, user.effectiveStreakDays)
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

        // Posts are loaded tolerantly — empty stays if rules deny or query fails.
        do {
            let result = try await postService.getPosts(byUser: userId, limit: 3)
            posts = result.posts
        } catch {
            AppLogger.firebase.warning("Failed to load posts: \(error.localizedDescription)")
            posts = []
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
            // Performance
            "first_run",
            "distance_5k",
            "distance_10k",
            "distance_21k",
            "distance_42k",
            "total_distance_100k",
            "runs_50",
            "runs_100",
            "endurance_60",
            "boost_5",
            "boost_25",
            "points_10k",
            "points_50k",
            "points_100k",
            "level_10",
            "level_25",
            // Territory
            "first_territory",
            "territory_25",
            "territory_100",
            // Exploration
            "early_bird",
            "night_owl",
            // Streak
            "streak_7",
            "streak_14",
            "streak_30",
            "streak_100"
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
