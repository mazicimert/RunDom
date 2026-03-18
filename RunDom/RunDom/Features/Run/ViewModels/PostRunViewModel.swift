import SwiftUI

@MainActor
final class PostRunViewModel: ObservableObject {

    // MARK: - Published State

    @Published var trailResult: TrailCalculator.TrailResult?
    @Published var isSaving = false
    @Published var isSaved = false
    @Published var errorMessage: String?
    @Published var didExtendStreak = false
    @Published var newStreakDays: Int?
    @Published var dailyChallengeReward: DailyChallengeReward?

    // MARK: - Properties

    var session: RunSession

    // MARK: - Services

    private let trailCalculator: TrailCalculator
    private let firestoreService: FirestoreService
    private let streakService: StreakService
    private let antiCheatService: AntiCheatService
    private let geocodingService: GeocodingService
    private let badgeService: BadgeService
    private let dailyChallengeService: DailyChallengeService

    // MARK: - Init

    init(
        session: RunSession,
        trailCalculator: TrailCalculator = TrailCalculator(),
        firestoreService: FirestoreService = FirestoreService(),
        streakService: StreakService = StreakService(),
        antiCheatService: AntiCheatService = AntiCheatService(),
        geocodingService: GeocodingService = .shared,
        badgeService: BadgeService = BadgeService(),
        dailyChallengeService: DailyChallengeService = DailyChallengeService()
    ) {
        self.session = session
        self.trailCalculator = trailCalculator
        self.firestoreService = firestoreService
        self.streakService = streakService
        self.antiCheatService = antiCheatService
        self.geocodingService = geocodingService
        self.badgeService = badgeService
        self.dailyChallengeService = dailyChallengeService
    }

    // MARK: - Calculate & Save

    func processRun(user: User) async {
        didExtendStreak = false
        newStreakDays = nil
        dailyChallengeReward = nil

        let latestUser = (try? await firestoreService.getUser(id: user.id)) ?? user

        // 1. Anti-cheat validation
        let validation = antiCheatService.validateRoute(
            points: session.route,
            visitedZones: Array(repeating: "", count: session.totalZonesVisited) // Simplified
        )

        guard validation.isValid else {
            errorMessage = "run.invalidRun".localized
            AppLogger.run.warning("Run rejected by anti-cheat: \(validation.flags)")
            return
        }

        // 2. Calculate trail points
        let todayTrail = (try? await firestoreService.getTodayTrail(userId: user.id)) ?? 0

        let result = trailCalculator.calculate(
            session: session,
            streakDays: latestUser.streakDays,
            hasDropzoneBoost: latestUser.hasActiveDropzoneBoost,
            todayTrail: todayTrail
        )

        trailResult = result
        session.trail = result.totalTrail

        let detectedNeighborhood = await detectedNeighborhoodFromRun()

        // 3. Save to Firebase
        isSaving = true
        do {
            try await firestoreService.saveRun(session)
            try await firestoreService.incrementUserTrail(
                userId: user.id,
                trail: result.totalTrail,
                distance: session.distance,
                neighborhood: detectedNeighborhood
            )

            // 4. Update streak
            let newStreakDays = streakService.updateStreak(
                currentStreakDays: latestUser.streakDays,
                lastRunDate: latestUser.lastRunDate
            )
            try await streakService.saveStreakUpdate(userId: user.id, newStreakDays: newStreakDays)
            self.newStreakDays = newStreakDays
            didExtendStreak = newStreakDays > latestUser.streakDays

            let dailyChallengeResult = try await dailyChallengeService.updateAfterRun(
                userId: user.id,
                run: session
            )
            dailyChallengeReward = dailyChallengeResult.reward

            Task {
                do {
                    try await badgeService.syncAndEvaluateBadges(userId: user.id)
                } catch {
                    AppLogger.game.warning("Badge sync failed after run: \(error.localizedDescription)")
                }
            }

            isSaved = true
            AppLogger.run.info("Run saved: \(self.session.id), trail=\(result.totalTrail)")
        } catch {
            errorMessage = "run.saveFailed".localized
            AppLogger.run.error("Failed to save run: \(error.localizedDescription)")
        }

        isSaving = false
    }

    private func detectedNeighborhoodFromRun() async -> String? {
        guard let coordinate = session.route.last?.coordinate ?? session.route.first?.coordinate else {
            return nil
        }

        return await geocodingService.neighborhoodName(for: coordinate)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Computed

    var distanceKm: Double {
        session.distance / 1000.0
    }

    var durationText: String {
        let duration = session.duration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var avgSpeedText: String {
        session.avgSpeed.formattedSpeed
    }

    var trailText: String {
        (trailResult?.totalTrail ?? 0).formattedTrail
    }

    var modeText: String {
        switch session.mode {
        case .normal: return "run.normalMode".localized
        case .boost:
            return session.isBoostActive ? "run.boostMode".localized : "run.boostCancelled".localized
        }
    }

    var streakExtendedText: String? {
        guard didExtendStreak, let days = newStreakDays else { return nil }
        return "run.streak".localized(with: "\(days)")
    }
}
