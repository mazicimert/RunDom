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
        let existingBadges = try await firestoreService.getBadges(userId: userId)

        let longestRunDistance = runs.map(\.distance).max() ?? 0
        let longestRunMinutes = runs.map(\.durationMinutes).max() ?? 0
        let totalRuns = max(user.totalRuns, runs.count)
        let totalDistance = max(user.totalDistance, runs.reduce(0.0) { $0 + $1.distance })
        let boostRuns = runs.filter { $0.mode == .boost }.count
        let totalTerritories = runs.reduce(0) { $0 + $1.territoriesCaptured }
        let streakDays = user.streakDays
        let totalPoints = user.totalTrail
        let level = PlayerLevel(totalTrail: user.totalTrail).level
        let hasEarlyRun = runs.contains { Calendar.current.component(.hour, from: $0.startDate) < 7 }
        let hasLateRun = runs.contains { Calendar.current.component(.hour, from: $0.startDate) >= 23 }

        let progressByBadgeId: [String: Double] = [
            Self.BadgeId.firstRun: Double(totalRuns),
            Self.BadgeId.distance5K: longestRunDistance,
            Self.BadgeId.distance10K: longestRunDistance,
            Self.BadgeId.distance21K: longestRunDistance,
            Self.BadgeId.distance42K: longestRunDistance,
            Self.BadgeId.totalDistance100K: totalDistance,
            Self.BadgeId.runs50: Double(totalRuns),
            Self.BadgeId.runs100: Double(totalRuns),
            Self.BadgeId.endurance60: longestRunMinutes,
            Self.BadgeId.boost5: Double(boostRuns),
            Self.BadgeId.boost25: Double(boostRuns),
            Self.BadgeId.points10K: totalPoints,
            Self.BadgeId.points50K: totalPoints,
            Self.BadgeId.points100K: totalPoints,
            Self.BadgeId.level10: Double(level),
            Self.BadgeId.level25: Double(level),
            Self.BadgeId.firstTerritory: Double(totalTerritories),
            Self.BadgeId.territory25: Double(totalTerritories),
            Self.BadgeId.territory100: Double(totalTerritories),
            Self.BadgeId.earlyBird: hasEarlyRun ? 1 : 0,
            Self.BadgeId.nightOwl: hasLateRun ? 1 : 0,
            Self.BadgeId.streak7: Double(streakDays),
            Self.BadgeId.streak14: Double(streakDays),
            Self.BadgeId.streak30: Double(streakDays),
            Self.BadgeId.streak100: Double(streakDays),
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

        // Prune any persisted badges that are no longer part of the catalog
        // (e.g. the retired dropzone badges) so they disappear for existing
        // users as well, not just new ones.
        let catalogIds = Set(Self.catalog.map(\.id))
        for staleBadge in existingBadges where !catalogIds.contains(staleBadge.id) {
            try await firestoreService.deleteBadge(badgeId: staleBadge.id, userId: userId)
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
        static let distance21K = "distance_21k"
        static let distance42K = "distance_42k"
        static let totalDistance100K = "total_distance_100k"
        static let runs50 = "runs_50"
        static let runs100 = "runs_100"
        static let endurance60 = "endurance_60"
        static let boost5 = "boost_5"
        static let boost25 = "boost_25"
        static let points10K = "points_10k"
        static let points50K = "points_50k"
        static let points100K = "points_100k"
        static let level10 = "level_10"
        static let level25 = "level_25"
        static let firstTerritory = "first_territory"
        static let territory25 = "territory_25"
        static let territory100 = "territory_100"
        static let earlyBird = "early_bird"
        static let nightOwl = "night_owl"
        static let streak7 = "streak_7"
        static let streak14 = "streak_14"
        static let streak30 = "streak_30"
        static let streak100 = "streak_100"
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
            id: BadgeId.distance21K,
            nameKey: "badge.distance_21k.name",
            descriptionKey: "badge.distance_21k.description",
            iconName: "flag.checkered",
            category: .performance,
            isSecret: false,
            targetValue: 21_100
        ),
        Badge(
            id: BadgeId.distance42K,
            nameKey: "badge.distance_42k.name",
            descriptionKey: "badge.distance_42k.description",
            iconName: "trophy.fill",
            category: .performance,
            isSecret: false,
            targetValue: 42_200
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
            id: BadgeId.runs50,
            nameKey: "badge.runs_50.name",
            descriptionKey: "badge.runs_50.description",
            iconName: "figure.run.square.stack",
            category: .performance,
            isSecret: false,
            targetValue: 50
        ),
        Badge(
            id: BadgeId.runs100,
            nameKey: "badge.runs_100.name",
            descriptionKey: "badge.runs_100.description",
            iconName: "medal.fill",
            category: .performance,
            isSecret: false,
            targetValue: 100
        ),
        Badge(
            id: BadgeId.endurance60,
            nameKey: "badge.endurance_60.name",
            descriptionKey: "badge.endurance_60.description",
            iconName: "stopwatch.fill",
            category: .performance,
            isSecret: false,
            targetValue: 60
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
            id: BadgeId.boost25,
            nameKey: "badge.boost_25.name",
            descriptionKey: "badge.boost_25.description",
            iconName: "bolt.circle.fill",
            category: .performance,
            isSecret: false,
            targetValue: 25
        ),
        Badge(
            id: BadgeId.points10K,
            nameKey: "badge.points_10k.name",
            descriptionKey: "badge.points_10k.description",
            iconName: "star.fill",
            category: .performance,
            isSecret: false,
            targetValue: 10_000
        ),
        Badge(
            id: BadgeId.points50K,
            nameKey: "badge.points_50k.name",
            descriptionKey: "badge.points_50k.description",
            iconName: "star.circle.fill",
            category: .performance,
            isSecret: false,
            targetValue: 50_000
        ),
        Badge(
            id: BadgeId.points100K,
            nameKey: "badge.points_100k.name",
            descriptionKey: "badge.points_100k.description",
            iconName: "star.square.fill",
            category: .performance,
            isSecret: false,
            targetValue: 100_000
        ),
        Badge(
            id: BadgeId.level10,
            nameKey: "badge.level_10.name",
            descriptionKey: "badge.level_10.description",
            iconName: "sparkles",
            category: .performance,
            isSecret: false,
            targetValue: 10
        ),
        Badge(
            id: BadgeId.level25,
            nameKey: "badge.level_25.name",
            descriptionKey: "badge.level_25.description",
            iconName: "wand.and.stars",
            category: .performance,
            isSecret: false,
            targetValue: 25
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
            id: BadgeId.earlyBird,
            nameKey: "badge.early_bird.name",
            descriptionKey: "badge.early_bird.description",
            iconName: "sunrise.fill",
            category: .exploration,
            isSecret: true,
            targetValue: 1
        ),
        Badge(
            id: BadgeId.nightOwl,
            nameKey: "badge.night_owl.name",
            descriptionKey: "badge.night_owl.description",
            iconName: "moon.stars.fill",
            category: .exploration,
            isSecret: false,
            targetValue: 1
        ),
        Badge(
            id: BadgeId.streak7,
            nameKey: "badge.streak_7.name",
            descriptionKey: "badge.streak_7.description",
            iconName: "flame",
            category: .streak,
            isSecret: false,
            targetValue: 7
        ),
        Badge(
            id: BadgeId.streak14,
            nameKey: "badge.streak_14.name",
            descriptionKey: "badge.streak_14.description",
            iconName: "flame.fill",
            category: .streak,
            isSecret: false,
            targetValue: 14
        ),
        Badge(
            id: BadgeId.streak30,
            nameKey: "badge.streak_30.name",
            descriptionKey: "badge.streak_30.description",
            iconName: "flame.circle",
            category: .streak,
            isSecret: false,
            targetValue: 30
        ),
        Badge(
            id: BadgeId.streak100,
            nameKey: "badge.streak_100.name",
            descriptionKey: "badge.streak_100.description",
            iconName: "flame.circle.fill",
            category: .streak,
            isSecret: false,
            targetValue: 100
        )
    ]
}
