import Foundation

/// Handles badge catalog seeding and rule-based unlocking.
final class BadgeService {

    // MARK: - Dependencies

    private let firestoreService: FirestoreService

    // MARK: - Init

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
    }

    // MARK: - Public API

    /// Ensures badge docs exist for the user and evaluates unlock conditions
    /// against current persisted data (runs, user profile, dropzone claims).
    func syncAndEvaluateBadges(userId: String) async throws {
        try await seedCatalogIfNeeded(userId: userId)

        guard let user = try await firestoreService.getUser(id: userId) else { return }

        let runs = try await firestoreService.getAllRuns(userId: userId)
        let dropzoneClaimCount = try await firestoreService.getClaimedDropzoneCount(userId: userId)
        let existingBadges = try await firestoreService.getBadges(userId: userId)

        let longestRunDistance = runs.map(\.distance).max() ?? 0
        let totalRuns = max(user.totalRuns, runs.count)
        let totalDistance = max(user.totalDistance, runs.reduce(0.0) { $0 + $1.distance })
        let boostRuns = runs.filter { $0.mode == .boost }.count
        let totalTerritories = runs.reduce(0) { $0 + $1.territoriesCaptured }
        let streakDays = user.streakDays

        let progressByBadgeId: [String: Double] = [
            Self.BadgeId.firstRun: Double(totalRuns),
            Self.BadgeId.distance5K: longestRunDistance,
            Self.BadgeId.distance10K: longestRunDistance,
            Self.BadgeId.totalDistance100K: totalDistance,
            Self.BadgeId.boost5: Double(boostRuns),
            Self.BadgeId.firstTerritory: Double(totalTerritories),
            Self.BadgeId.territory25: Double(totalTerritories),
            Self.BadgeId.territory100: Double(totalTerritories),
            Self.BadgeId.firstDropzone: Double(dropzoneClaimCount),
            Self.BadgeId.dropzone5: Double(dropzoneClaimCount),
            Self.BadgeId.streak7: Double(streakDays),
            Self.BadgeId.streak30: Double(streakDays),
        ]

        var badgeById = Dictionary(uniqueKeysWithValues: existingBadges.map { ($0.id, $0) })

        for catalogBadge in Self.catalog {
            let existingBadge = badgeById[catalogBadge.id]
            var badge = Badge(
                id: catalogBadge.id,
                nameKey: catalogBadge.nameKey,
                descriptionKey: catalogBadge.descriptionKey,
                iconName: catalogBadge.iconName,
                category: catalogBadge.category,
                isSecret: catalogBadge.isSecret,
                isUnlocked: existingBadge?.isUnlocked ?? false,
                unlockedAt: existingBadge?.unlockedAt,
                progress: existingBadge?.progress ?? 0,
                targetValue: catalogBadge.targetValue
            )

            let newProgress = max(badge.progress, progressByBadgeId[catalogBadge.id] ?? 0)
            let shouldUnlock = newProgress >= badge.targetValue
            var didChange = existingBadge == nil ||
                existingBadge?.nameKey != catalogBadge.nameKey ||
                existingBadge?.descriptionKey != catalogBadge.descriptionKey ||
                existingBadge?.iconName != catalogBadge.iconName ||
                existingBadge?.category != catalogBadge.category ||
                existingBadge?.isSecret != catalogBadge.isSecret ||
                abs((existingBadge?.targetValue ?? 0) - catalogBadge.targetValue) > 0.0001

            if abs(badge.progress - newProgress) > 0.0001 {
                badge.progress = newProgress
                didChange = true
            }

            if shouldUnlock && !badge.isUnlocked {
                badge.isUnlocked = true
                badge.unlockedAt = Date()
                didChange = true
                AnalyticsService.logBadgeUnlocked(
                    badgeId: badge.id,
                    category: badge.category.rawValue
                )
            }

            if badge.isUnlocked && badge.unlockedAt == nil {
                badge.unlockedAt = Date()
                didChange = true
            }

            if didChange {
                try await firestoreService.upsertBadge(badge, userId: userId)
                badgeById[badge.id] = badge
            }
        }
    }

    // MARK: - Catalog Seed

    private func seedCatalogIfNeeded(userId: String) async throws {
        let existing = try await firestoreService.getBadges(userId: userId)
        let existingIds = Set(existing.map(\.id))

        for badge in Self.catalog where !existingIds.contains(badge.id) {
            try await firestoreService.upsertBadge(badge, userId: userId)
        }
    }

    // MARK: - Badge Catalog

    private enum BadgeId {
        static let firstRun = "first_run"
        static let distance5K = "distance_5k"
        static let distance10K = "distance_10k"
        static let totalDistance100K = "total_distance_100k"
        static let boost5 = "boost_5"
        static let firstTerritory = "first_territory"
        static let territory25 = "territory_25"
        static let territory100 = "territory_100"
        static let firstDropzone = "first_dropzone"
        static let dropzone5 = "dropzone_5"
        static let streak7 = "streak_7"
        static let streak30 = "streak_30"
    }

    private static let catalog: [Badge] = [
        Badge(
            id: BadgeId.firstRun,
            nameKey: "badge.first_run.name",
            descriptionKey: "badge.first_run.description",
            iconName: "figure.run",
            category: .performance,
            isSecret: false,
            targetValue: 1
        ),
        Badge(
            id: BadgeId.distance5K,
            nameKey: "badge.distance_5k.name",
            descriptionKey: "badge.distance_5k.description",
            iconName: "figure.run.circle",
            category: .performance,
            isSecret: false,
            targetValue: 5_000
        ),
        Badge(
            id: BadgeId.distance10K,
            nameKey: "badge.distance_10k.name",
            descriptionKey: "badge.distance_10k.description",
            iconName: "figure.run.circle.fill",
            category: .performance,
            isSecret: false,
            targetValue: 10_000
        ),
        Badge(
            id: BadgeId.totalDistance100K,
            nameKey: "badge.total_distance_100k.name",
            descriptionKey: "badge.total_distance_100k.description",
            iconName: "point.topleft.down.to.point.bottomright.curvepath",
            category: .performance,
            isSecret: false,
            targetValue: 100_000
        ),
        Badge(
            id: BadgeId.boost5,
            nameKey: "badge.boost_5.name",
            descriptionKey: "badge.boost_5.description",
            iconName: "bolt.fill",
            category: .performance,
            isSecret: false,
            targetValue: 5
        ),
        Badge(
            id: BadgeId.firstTerritory,
            nameKey: "badge.first_territory.name",
            descriptionKey: "badge.first_territory.description",
            iconName: "hexagon.fill",
            category: .territory,
            isSecret: false,
            targetValue: 1
        ),
        Badge(
            id: BadgeId.territory25,
            nameKey: "badge.territory_25.name",
            descriptionKey: "badge.territory_25.description",
            iconName: "shield.fill",
            category: .territory,
            isSecret: false,
            targetValue: 25
        ),
        Badge(
            id: BadgeId.territory100,
            nameKey: "badge.territory_100.name",
            descriptionKey: "badge.territory_100.description",
            iconName: "crown.fill",
            category: .territory,
            isSecret: false,
            targetValue: 100
        ),
        Badge(
            id: BadgeId.firstDropzone,
            nameKey: "badge.first_dropzone.name",
            descriptionKey: "badge.first_dropzone.description",
            iconName: "mappin.and.ellipse",
            category: .dropzone,
            isSecret: false,
            targetValue: 1
        ),
        Badge(
            id: BadgeId.dropzone5,
            nameKey: "badge.dropzone_5.name",
            descriptionKey: "badge.dropzone_5.description",
            iconName: "mappin.circle.fill",
            category: .dropzone,
            isSecret: false,
            targetValue: 5
        ),
        Badge(
            id: BadgeId.streak7,
            nameKey: "badge.streak_7.name",
            descriptionKey: "badge.streak_7.description",
            iconName: "flame.fill",
            category: .streak,
            isSecret: false,
            targetValue: 7
        ),
        Badge(
            id: BadgeId.streak30,
            nameKey: "badge.streak_30.name",
            descriptionKey: "badge.streak_30.description",
            iconName: "flame.circle.fill",
            category: .streak,
            isSecret: false,
            targetValue: 30
        )
    ]
}
