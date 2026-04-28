import SwiftUI

@MainActor
final class AIRunAnalysisViewModel: ObservableObject {

    // MARK: - State

    enum State: Equatable {
        case idle
        case loading
        case loaded(AIRunAnalysisResult)
        case fallback(AIRunAnalysisResult, errorMessage: String)
    }

    @Published private(set) var state: State = .idle

    // MARK: - Inputs

    let session: RunSession
    let trailResult: TrailCalculator.TrailResult
    let neighborhood: String?

    // MARK: - Services

    private let aiService: AIAnalysisService
    private let firestoreService: FirestoreService
    private let localizationManager: LocalizationManager

    // MARK: - Init

    init(
        session: RunSession,
        trailResult: TrailCalculator.TrailResult,
        neighborhood: String? = nil,
        aiService: AIAnalysisService = .shared,
        firestoreService: FirestoreService = FirestoreService(),
        localizationManager: LocalizationManager = .shared
    ) {
        self.session = session
        self.trailResult = trailResult
        self.neighborhood = neighborhood
        self.aiService = aiService
        self.firestoreService = firestoreService
        self.localizationManager = localizationManager
    }

    // MARK: - Actions

    func generateIfNeeded(user: User) async {
        guard case .idle = state else { return }
        await generate(user: user)
    }

    func generate(user: User) async {
        state = .loading
        AnalyticsService.logAIRunAnalysisRequested(mode: session.mode)

        let aiEnabled = UserDefaults.standard.object(forKey: AppConstants.UserDefaultsKeys.aiAnalysisEnabled) as? Bool ?? true

        if !aiEnabled {
            let template = TemplateInsightService.makeRunAnalysis(
                session: session,
                trailResult: trailResult,
                user: user,
                recentRuns: [],
                neighborhood: neighborhood
            )
            state = .loaded(AIRunAnalysisResult(analysis: template, source: .template))
            AnalyticsService.logAIRunAnalysisLoaded(source: .template)
            return
        }

        let recentRuns = (try? await firestoreService.getRunSessions(userId: user.id, limit: 6)) ?? []
        let recentBadges = await Self.recentBadges(firestoreService: firestoreService, userId: user.id)

        do {
            let analysis = try await aiService.analyzeRun(
                session: session,
                trailResult: trailResult,
                user: user,
                recentRuns: recentRuns,
                recentBadges: recentBadges,
                neighborhood: neighborhood,
                languageCode: localizationManager.selectedLanguageCode
            )
            state = .loaded(AIRunAnalysisResult(analysis: analysis, source: .ai))
            AnalyticsService.logAIRunAnalysisLoaded(source: .ai)
        } catch {
            AppLogger.firebase.warning("AI run analysis failed, using template: \(error.localizedDescription)")
            let template = TemplateInsightService.makeRunAnalysis(
                session: session,
                trailResult: trailResult,
                user: user,
                recentRuns: recentRuns,
                neighborhood: neighborhood
            )
            let errorMessage = (error as? AIAnalysisService.AIError)?.errorDescription
                ?? "ai.error.unavailable".localized
            state = .fallback(
                AIRunAnalysisResult(analysis: template, source: .template),
                errorMessage: errorMessage
            )
            AnalyticsService.logAIRunAnalysisFailed(reason: errorTag(error))
        }
    }

    var resolvedAnalysis: AIRunAnalysisResult? {
        switch state {
        case .idle, .loading:
            return nil
        case .loaded(let result):
            return result
        case .fallback(let result, _):
            return result
        }
    }

    var fallbackErrorMessage: String? {
        if case .fallback(_, let message) = state {
            return message
        }
        return nil
    }

    private func errorTag(_ error: Error) -> String {
        if let aiError = error as? AIAnalysisService.AIError {
            switch aiError {
            case .minimumThresholdsUnmet: return "min_thresholds"
            case .rateLimited: return "rate_limited"
            case .unauthenticated: return "unauthenticated"
            case .unavailable: return "unavailable"
            case .invalidResponse: return "invalid_response"
            case .underlying: return "underlying"
            }
        }
        return "unknown"
    }

    static func recentBadges(firestoreService: FirestoreService, userId: String) async -> [Badge] {
        guard let badges = try? await firestoreService.getBadges(userId: userId) else { return [] }
        return badges
            .filter { $0.isUnlocked }
            .sorted { lhs, rhs in
                (lhs.unlockedAt ?? .distantPast) > (rhs.unlockedAt ?? .distantPast)
            }
            .prefix(6)
            .map { $0 }
    }
}

@MainActor
final class AIWeeklyAnalysisViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case loading
        case loaded(AIWeeklyAnalysisResult)
        case fallback(AIWeeklyAnalysisResult, errorMessage: String)
    }

    @Published private(set) var state: State = .idle

    private let aiService: AIAnalysisService
    private let firestoreService: FirestoreService
    private let seasonService: SeasonService
    private let localizationManager: LocalizationManager

    init(
        aiService: AIAnalysisService = .shared,
        firestoreService: FirestoreService = FirestoreService(),
        seasonService: SeasonService = SeasonService(),
        localizationManager: LocalizationManager = .shared
    ) {
        self.aiService = aiService
        self.firestoreService = firestoreService
        self.seasonService = seasonService
        self.localizationManager = localizationManager
    }

    func generate(user: User) async {
        state = .loading
        AnalyticsService.logAIWeeklyAnalysisRequested()

        let aiEnabled = UserDefaults.standard.object(forKey: AppConstants.UserDefaultsKeys.aiAnalysisEnabled) as? Bool ?? true

        let now = Date()
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let weekday = calendar.component(.weekday, from: now)
        let daysSinceMonday = (weekday + 5) % 7
        let startOfThisWeek = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -daysSinceMonday, to: now) ?? now
        )
        let startOfLastWeek = calendar.date(byAdding: .day, value: -7, to: startOfThisWeek) ?? startOfThisWeek

        let weekId = seasonService.generateCurrentSeason().id
        let runsThisWeek = (try? await firestoreService.getRuns(
            userId: user.id,
            from: startOfThisWeek,
            to: now
        )) ?? []
        let runsLastWeek = (try? await firestoreService.getRuns(
            userId: user.id,
            from: startOfLastWeek,
            to: startOfThisWeek
        )) ?? []

        guard !runsThisWeek.isEmpty else {
            let template = TemplateInsightService.makeWeeklyAnalysis(
                runsThisWeek: [],
                runsLastWeek: runsLastWeek,
                user: user
            )
            state = .fallback(
                AIWeeklyAnalysisResult(analysis: template, source: .template),
                errorMessage: "ai.weekly.error.noRuns".localized
            )
            AnalyticsService.logAIWeeklyAnalysisFailed(reason: "no_runs")
            return
        }

        if !aiEnabled {
            let template = TemplateInsightService.makeWeeklyAnalysis(
                runsThisWeek: runsThisWeek,
                runsLastWeek: runsLastWeek,
                user: user
            )
            state = .loaded(AIWeeklyAnalysisResult(analysis: template, source: .template))
            AnalyticsService.logAIWeeklyAnalysisLoaded(source: .template)
            return
        }

        let recentBadges = await AIRunAnalysisViewModel.recentBadges(firestoreService: firestoreService, userId: user.id)

        do {
            let analysis = try await aiService.analyzeWeek(
                weekId: weekId,
                runsThisWeek: runsThisWeek,
                runsLastWeek: runsLastWeek,
                user: user,
                recentBadges: recentBadges,
                neighborhood: user.neighborhood,
                languageCode: localizationManager.selectedLanguageCode
            )
            state = .loaded(AIWeeklyAnalysisResult(analysis: analysis, source: .ai))
            AnalyticsService.logAIWeeklyAnalysisLoaded(source: .ai)
        } catch {
            AppLogger.firebase.warning("AI weekly analysis failed, using template: \(error.localizedDescription)")
            let template = TemplateInsightService.makeWeeklyAnalysis(
                runsThisWeek: runsThisWeek,
                runsLastWeek: runsLastWeek,
                user: user
            )
            let errorMessage = (error as? AIAnalysisService.AIError)?.errorDescription
                ?? "ai.error.unavailable".localized
            state = .fallback(
                AIWeeklyAnalysisResult(analysis: template, source: .template),
                errorMessage: errorMessage
            )
            AnalyticsService.logAIWeeklyAnalysisFailed(reason: errorTag(error))
        }
    }

    var resolvedAnalysis: AIWeeklyAnalysisResult? {
        switch state {
        case .idle, .loading:
            return nil
        case .loaded(let result):
            return result
        case .fallback(let result, _):
            return result
        }
    }

    var fallbackErrorMessage: String? {
        if case .fallback(_, let message) = state {
            return message
        }
        return nil
    }

    private func errorTag(_ error: Error) -> String {
        if let aiError = error as? AIAnalysisService.AIError {
            switch aiError {
            case .minimumThresholdsUnmet: return "min_thresholds"
            case .rateLimited: return "rate_limited"
            case .unauthenticated: return "unauthenticated"
            case .unavailable: return "unavailable"
            case .invalidResponse: return "invalid_response"
            case .underlying: return "underlying"
            }
        }
        return "unknown"
    }
}
