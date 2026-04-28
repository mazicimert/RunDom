import Foundation
import FirebaseFunctions

/// Talks to the analyzeRun / analyzeWeek Cloud Functions.
/// All Gemini calls go through this proxy so the API key never ships to clients.
final class AIAnalysisService {

    // MARK: - Errors

    enum AIError: LocalizedError {
        case minimumThresholdsUnmet
        case rateLimited
        case unauthenticated
        case unavailable
        case invalidResponse
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .minimumThresholdsUnmet:
                return "ai.error.minThresholds".localized
            case .rateLimited:
                return "ai.error.rateLimited".localized
            case .unauthenticated:
                return "ai.error.unauthenticated".localized
            case .unavailable:
                return "ai.error.unavailable".localized
            case .invalidResponse:
                return "ai.error.invalidResponse".localized
            case .underlying:
                return "ai.error.unavailable".localized
            }
        }
    }

    // MARK: - Singleton

    static let shared = AIAnalysisService()

    // MARK: - Functions

    private let functions: Functions

    private init() {
        functions = Functions.functions(region: "europe-west1")
    }

    // MARK: - Run Analysis

    func analyzeRun(
        session: RunSession,
        trailResult: TrailCalculator.TrailResult,
        user: User,
        recentRuns: [RunSession],
        recentBadges: [Badge],
        neighborhood: String?,
        languageCode: String
    ) async throws -> AIRunAnalysis {
        guard session.distance >= AIRunAnalysisLimits.minDistanceMeters,
              session.duration >= AIRunAnalysisLimits.minDurationSeconds else {
            throw AIError.minimumThresholdsUnmet
        }

        let payload = buildRunPayload(
            session: session,
            trailResult: trailResult,
            user: user,
            recentRuns: recentRuns,
            recentBadges: recentBadges,
            neighborhood: neighborhood,
            languageCode: languageCode
        )

        return try await callRun(payload: payload)
    }

    // MARK: - Weekly Analysis

    func analyzeWeek(
        weekId: String,
        runsThisWeek: [RunSession],
        runsLastWeek: [RunSession],
        user: User,
        recentBadges: [Badge],
        neighborhood: String?,
        languageCode: String
    ) async throws -> AIWeeklyAnalysis {
        guard !runsThisWeek.isEmpty else {
            throw AIError.minimumThresholdsUnmet
        }

        let payload = buildWeeklyPayload(
            weekId: weekId,
            runsThisWeek: runsThisWeek,
            runsLastWeek: runsLastWeek,
            user: user,
            recentBadges: recentBadges,
            neighborhood: neighborhood,
            languageCode: languageCode
        )

        return try await callWeek(payload: payload)
    }

    // MARK: - Function Calls

    private func callRun(payload: [String: Any]) async throws -> AIRunAnalysis {
        do {
            let result = try await functions.httpsCallable("analyzeRun").call(payload)
            return try decode(AIRunAnalysis.self, from: result.data)
        } catch {
            throw mapError(error)
        }
    }

    private func callWeek(payload: [String: Any]) async throws -> AIWeeklyAnalysis {
        do {
            let result = try await functions.httpsCallable("analyzeWeek").call(payload)
            return try decode(AIWeeklyAnalysis.self, from: result.data)
        } catch {
            throw mapError(error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Any) throws -> T {
        guard JSONSerialization.isValidJSONObject(data) else {
            throw AIError.invalidResponse
        }
        let raw = try JSONSerialization.data(withJSONObject: data)
        do {
            return try JSONDecoder().decode(T.self, from: raw)
        } catch {
            AppLogger.firebase.warning("AI response decode failed: \(error.localizedDescription)")
            throw AIError.invalidResponse
        }
    }

    private func mapError(_ error: Error) -> AIError {
        let nsError = error as NSError
        if nsError.domain == FunctionsErrorDomain,
           let code = FunctionsErrorCode(rawValue: nsError.code) {
            switch code {
            case .resourceExhausted:
                return .rateLimited
            case .unauthenticated:
                return .unauthenticated
            case .failedPrecondition:
                return .minimumThresholdsUnmet
            case .unavailable, .internal, .deadlineExceeded:
                return .unavailable
            default:
                return .underlying(error)
            }
        }
        return .underlying(error)
    }

    // MARK: - Payload Builders

    private func buildRunPayload(
        session: RunSession,
        trailResult: TrailCalculator.TrailResult,
        user: User,
        recentRuns: [RunSession],
        recentBadges: [Badge],
        neighborhood: String?,
        languageCode: String
    ) -> [String: Any] {
        let now = Date()
        let recent = recentRuns
            .filter { $0.id != session.id }
            .prefix(5)
            .map { run -> [String: Any] in
                let daysAgo = max(0, Calendar.current.dateComponents([.day], from: run.startDate, to: now).day ?? 0)
                return [
                    "distanceKm": run.distance / 1000.0,
                    "durationMinutes": run.duration / 60.0,
                    "avgSpeedKmh": run.avgSpeed,
                    "trail": run.trail,
                    "mode": run.mode.rawValue,
                    "territoriesCaptured": run.territoriesCaptured,
                    "uniqueZoneRatio": run.uniqueZoneRatio,
                    "daysAgo": daysAgo
                ]
            }

        var payload: [String: Any] = [
            "runId": session.id,
            "language": languageCode,
            "distanceMeters": session.distance,
            "durationSeconds": session.duration,
            "avgSpeedKmh": session.avgSpeed,
            "peakSpeedKmh": session.maxSpeed,
            "mode": session.mode.rawValue,
            "isBoostKept": session.isBoostActive,
            "territoriesCaptured": session.territoriesCaptured,
            "uniqueZonesVisited": session.uniqueZonesVisited,
            "totalZonesVisited": session.totalZonesVisited,
            "trail": trailResult.totalTrail,
            "trailBreakdown": [
                "base": trailResult.basePoints,
                "speed": trailResult.speedMultiplier,
                "duration": trailResult.durationMultiplier,
                "zone": trailResult.zoneMultiplier,
                "streak": trailResult.streakMultiplier,
                "mode": trailResult.modeMultiplier,
                "antiFarm": trailResult.antiFarmMultiplier,
                "wasCapped": trailResult.wasCapped,
                "wasDailyCapped": trailResult.wasDailyCapped
            ],
            "streakDays": user.streakDays,
            "recentRuns": Array(recent),
            "recentBadges": recentBadges.map {
                ["id": $0.id, "category": $0.category.rawValue]
            },
            "seasonTrail": user.currentSeasonTrail,
            "hasActiveDropzoneBoost": user.hasActiveDropzoneBoost
        ]

        if let neighborhood = neighborhood?.trimmingCharacters(in: .whitespacesAndNewlines),
           !neighborhood.isEmpty {
            payload["neighborhood"] = neighborhood
        }

        return payload
    }

    private func buildWeeklyPayload(
        weekId: String,
        runsThisWeek: [RunSession],
        runsLastWeek: [RunSession],
        user: User,
        recentBadges: [Badge],
        neighborhood: String?,
        languageCode: String
    ) -> [String: Any] {
        let totalDistance = runsThisWeek.reduce(0) { $0 + $1.distance }
        let totalDuration = runsThisWeek.reduce(0) { $0 + $1.duration }
        let totalTrail = runsThisWeek.reduce(0) { $0 + $1.trail }
        let avgSpeed = runsThisWeek.isEmpty ? 0 :
            runsThisWeek.reduce(0) { $0 + $1.avgSpeed } / Double(runsThisWeek.count)
        let bestSingleRun = runsThisWeek.max(by: { $0.trail < $1.trail })?.trail ?? 0
        let longestRun = runsThisWeek.max(by: { $0.distance < $1.distance })?.distance ?? 0
        let uniqueZones = runsThisWeek.reduce(0) { $0 + $1.uniqueZonesVisited }
        let totalZones = runsThisWeek.reduce(0) { $0 + $1.totalZonesVisited }
        let territoriesCaptured = runsThisWeek.reduce(0) { $0 + $1.territoriesCaptured }
        let boostRuns = runsThisWeek.filter { $0.mode == .boost }
        let boostKept = boostRuns.filter { $0.isBoostActive }

        let lastWeekTrail = runsLastWeek.reduce(0) { $0 + $1.trail }
        let lastWeekDistance = runsLastWeek.reduce(0) { $0 + $1.distance }

        let trailChange = lastWeekTrail > 0 ? (totalTrail - lastWeekTrail) / lastWeekTrail : 0
        let distanceChange = lastWeekDistance > 0 ? (totalDistance - lastWeekDistance) / lastWeekDistance : 0

        var payload: [String: Any] = [
            "weekId": weekId,
            "language": languageCode,
            "totalRuns": runsThisWeek.count,
            "totalDistanceMeters": totalDistance,
            "totalDurationSeconds": totalDuration,
            "totalTrail": totalTrail,
            "avgSpeedKmh": avgSpeed,
            "bestSingleRunTrail": bestSingleRun,
            "longestSingleRunMeters": longestRun,
            "uniqueZonesVisited": uniqueZones,
            "totalZonesVisited": totalZones,
            "territoriesCaptured": territoriesCaptured,
            "streakDaysAtEndOfWeek": user.streakDays,
            "boostRunCount": boostRuns.count,
            "boostKeptCount": boostKept.count,
            "weekOverWeekTrailChange": trailChange,
            "weekOverWeekDistanceChange": distanceChange,
            "recentBadges": recentBadges.map {
                ["id": $0.id, "category": $0.category.rawValue]
            }
        ]

        if let neighborhood = neighborhood?.trimmingCharacters(in: .whitespacesAndNewlines),
           !neighborhood.isEmpty {
            payload["neighborhood"] = neighborhood
        }

        return payload
    }
}

// MARK: - Limits

enum AIRunAnalysisLimits {
    static let minDistanceMeters: Double = 300
    static let minDurationSeconds: Double = 180
}
