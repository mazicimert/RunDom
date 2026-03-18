import Foundation

final class DailyChallengeService {

    private struct Rotation {
        let dateKey: String
        let safeChallenge: DailyChallengeTemplate
        let difficultChallenge: DailyChallengeTemplate

        func challenge(id: String?) -> DailyChallengeTemplate? {
            guard let id else { return nil }
            if safeChallenge.id == id {
                return safeChallenge
            }
            if difficultChallenge.id == id {
                return difficultChallenge
            }
            return nil
        }
    }

    struct SelectionResult {
        let state: DailyChallengeState?
        let didGrantReward: Bool
        let reward: DailyChallengeReward?
    }

    struct RunUpdateResult {
        let state: DailyChallengeState?
        let reward: DailyChallengeReward?
    }

    enum DailyChallengeError: Error {
        case noTemplates
        case invalidSelection
    }

    private let firestoreService: FirestoreService

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
    }

    func loadDailyState(userId: String, on date: Date = Date()) async throws -> DailyChallengeState? {
        let templates = try await firestoreService.getActiveDailyChallengeTemplates()
        guard let rotation = rotation(from: templates, on: date) else { return nil }

        guard var progress = try await firestoreService.getDailyChallengeProgress(
            userId: userId,
            dateKey: rotation.dateKey
        ) else {
            return DailyChallengeState(
                dateKey: rotation.dateKey,
                safeChallenge: rotation.safeChallenge,
                difficultChallenge: rotation.difficultChallenge,
                progress: nil
            )
        }

        progress.safeChallengeId = rotation.safeChallenge.id
        progress.difficultChallengeId = rotation.difficultChallenge.id

        if let selectedChallenge = rotation.challenge(id: progress.selectedChallengeId) {
            let currentProgress = try await currentProgressValue(
                userId: userId,
                metricType: selectedChallenge.metricType,
                on: date
            )
            progress.progressValue = currentProgress
            progress.isCompleted = currentProgress >= selectedChallenge.targetValue
            try await firestoreService.upsertDailyChallengeProgress(progress, userId: userId)
        }

        return DailyChallengeState(
            dateKey: rotation.dateKey,
            safeChallenge: rotation.safeChallenge,
            difficultChallenge: rotation.difficultChallenge,
            progress: progress
        )
    }

    func selectChallenge(
        userId: String,
        challengeId: String,
        on date: Date = Date()
    ) async throws -> SelectionResult {
        let templates = try await firestoreService.getActiveDailyChallengeTemplates()
        guard let rotation = rotation(from: templates, on: date) else {
            throw DailyChallengeError.noTemplates
        }

        if let existing = try await firestoreService.getDailyChallengeProgress(
            userId: userId,
            dateKey: rotation.dateKey
        ), existing.selectedChallengeId != nil {
            let state = try await loadDailyState(userId: userId, on: date)
            return SelectionResult(state: state, didGrantReward: false, reward: nil)
        }

        guard let selectedChallenge = rotation.challenge(id: challengeId) else {
            throw DailyChallengeError.invalidSelection
        }

        let progressValue = try await currentProgressValue(
            userId: userId,
            metricType: selectedChallenge.metricType,
            on: date
        )

        var progress = UserDailyChallengeProgress(
            dateKey: rotation.dateKey,
            safeChallengeId: rotation.safeChallenge.id,
            difficultChallengeId: rotation.difficultChallenge.id,
            selectedChallengeId: selectedChallenge.id,
            progressValue: progressValue,
            isCompleted: progressValue >= selectedChallenge.targetValue,
            rewardGranted: false,
            completedAt: nil,
            completedRunId: nil
        )

        var reward: DailyChallengeReward?
        if progress.isCompleted {
            try await firestoreService.grantDailyChallengeReward(
                userId: userId,
                bonusTrail: selectedChallenge.bonusTrail
            )
            progress.rewardGranted = true
            progress.completedAt = Date()
            reward = DailyChallengeReward(
                challengeTitle: selectedChallenge.localizedTitle,
                bonusTrail: selectedChallenge.bonusTrail
            )
        }

        try await firestoreService.upsertDailyChallengeProgress(progress, userId: userId)

        let state = DailyChallengeState(
            dateKey: rotation.dateKey,
            safeChallenge: rotation.safeChallenge,
            difficultChallenge: rotation.difficultChallenge,
            progress: progress
        )

        return SelectionResult(state: state, didGrantReward: reward != nil, reward: reward)
    }

    func updateAfterRun(userId: String, run: RunSession) async throws -> RunUpdateResult {
        let templates = try await firestoreService.getActiveDailyChallengeTemplates()
        guard let rotation = rotation(from: templates, on: run.startDate) else {
            return RunUpdateResult(state: nil, reward: nil)
        }

        guard var progress = try await firestoreService.getDailyChallengeProgress(
            userId: userId,
            dateKey: rotation.dateKey
        ), let selectedChallenge = rotation.challenge(id: progress.selectedChallengeId) else {
            return RunUpdateResult(
                state: DailyChallengeState(
                    dateKey: rotation.dateKey,
                    safeChallenge: rotation.safeChallenge,
                    difficultChallenge: rotation.difficultChallenge,
                    progress: nil
                ),
                reward: nil
            )
        }

        let progressValue = try await currentProgressValue(
            userId: userId,
            metricType: selectedChallenge.metricType,
            on: run.startDate
        )

        progress.safeChallengeId = rotation.safeChallenge.id
        progress.difficultChallengeId = rotation.difficultChallenge.id
        progress.progressValue = progressValue
        progress.isCompleted = progressValue >= selectedChallenge.targetValue

        var reward: DailyChallengeReward?
        if progress.isCompleted && !progress.rewardGranted {
            try await firestoreService.grantDailyChallengeReward(
                userId: userId,
                bonusTrail: selectedChallenge.bonusTrail
            )
            progress.rewardGranted = true
            progress.completedAt = Date()
            progress.completedRunId = run.id
            reward = DailyChallengeReward(
                challengeTitle: selectedChallenge.localizedTitle,
                bonusTrail: selectedChallenge.bonusTrail
            )
        }

        try await firestoreService.upsertDailyChallengeProgress(progress, userId: userId)

        return RunUpdateResult(
            state: DailyChallengeState(
                dateKey: rotation.dateKey,
                safeChallenge: rotation.safeChallenge,
                difficultChallenge: rotation.difficultChallenge,
                progress: progress
            ),
            reward: reward
        )
    }

    func shouldShowDailyPrompt() -> Bool {
        let todayKey = Self.dateKey(for: Date())
        let lastShown = UserDefaults.standard.string(
            forKey: AppConstants.UserDefaultsKeys.lastDailyChallengePromptDateKey
        )
        return lastShown != todayKey
    }

    func hasAvailableChallenges(on date: Date = Date()) async -> Bool {
        do {
            let templates = try await firestoreService.getActiveDailyChallengeTemplates()
            return rotation(from: templates, on: date) != nil
        } catch {
            return false
        }
    }

    func markDailyPromptShown() {
        UserDefaults.standard.set(
            Self.dateKey(for: Date()),
            forKey: AppConstants.UserDefaultsKeys.lastDailyChallengePromptDateKey
        )
    }

    static func dateKey(for date: Date) -> String {
        DailyChallengeService.dateFormatter.string(
            from: DailyChallengeService.challengeCalendar.startOfDay(for: date)
        )
    }

    private func currentProgressValue(
        userId: String,
        metricType: DailyChallengeMetricType,
        on date: Date
    ) async throws -> Double {
        let startOfDay = Self.startOfDay(for: date)
        let endOfDay = Self.endOfDay(for: date)
        let runs = try await firestoreService.getRuns(
            userId: userId,
            from: startOfDay,
            to: endOfDay
        )

        switch metricType {
        case .durationMinutes:
            return runs.reduce(0) { $0 + $1.durationMinutes }
        case .distanceMeters:
            return runs.reduce(0) { $0 + $1.distance }
        }
    }

    private func rotation(
        from templates: [DailyChallengeTemplate],
        on date: Date
    ) -> Rotation? {
        let safeTemplates = templates
            .filter { $0.isActive && $0.difficulty == .safe }
            .sorted { lhs, rhs in
                lhs.sortOrder == rhs.sortOrder ? lhs.id < rhs.id : lhs.sortOrder < rhs.sortOrder
            }

        let difficultTemplates = templates
            .filter { $0.isActive && $0.difficulty == .difficult }
            .sorted { lhs, rhs in
                lhs.sortOrder == rhs.sortOrder ? lhs.id < rhs.id : lhs.sortOrder < rhs.sortOrder
            }

        guard !safeTemplates.isEmpty, !difficultTemplates.isEmpty else {
            return nil
        }

        let daySeed = Self.daySeed(for: date)
        let safeIndex = daySeed % safeTemplates.count
        let difficultIndex = (daySeed * 2 + 1) % difficultTemplates.count

        return Rotation(
            dateKey: Self.dateKey(for: date),
            safeChallenge: safeTemplates[safeIndex],
            difficultChallenge: difficultTemplates[difficultIndex]
        )
    }

    private static func startOfDay(for date: Date) -> Date {
        DailyChallengeService.challengeCalendar.startOfDay(for: date)
    }

    private static func endOfDay(for date: Date) -> Date {
        guard let nextDay = DailyChallengeService.challengeCalendar.date(
            byAdding: .day,
            value: 1,
            to: DailyChallengeService.startOfDay(for: date)
        ) else {
            return date
        }
        return nextDay
    }

    private static func daySeed(for date: Date) -> Int {
        Int(DailyChallengeService.startOfDay(for: date).timeIntervalSinceReferenceDate / 86_400)
    }

    private static let challengeCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = DailyChallengeService.challengeCalendar
        formatter.timeZone = DailyChallengeService.challengeCalendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
