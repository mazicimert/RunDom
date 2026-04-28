import Foundation

/// Rule-based fallback that produces an AI-shaped analysis without calling the cloud.
/// Used when the AI cloud function is unavailable (network, quota, parsing) so the user
/// never sees a blank screen, AND when the user disabled AI Analysis in settings.
enum TemplateInsightService {

    // MARK: - Run

    static func makeRunAnalysis(
        session: RunSession,
        trailResult: TrailCalculator.TrailResult,
        user: User,
        recentRuns: [RunSession],
        neighborhood: String?
    ) -> AIRunAnalysis {
        let distanceText = (session.distance / 1000.0).formattedDistance
        let durationText = formattedDuration(session.duration)
        let trailText = trailResult.totalTrail.formattedTrail
        let pointsUnit = "trail.unit".localized
        let neighborhoodText = neighborhood?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let summary = "ai.template.run.summary".localized(
            with: distanceText,
            durationText,
            trailText,
            pointsUnit
        )

        var highlights: [String] = []

        // Mode highlight
        switch session.mode {
        case .normal:
            highlights.append("ai.template.run.highlight.normal".localized)
        case .boost:
            if session.isBoostActive {
                highlights.append("ai.template.run.highlight.boostKept".localized(with: session.avgSpeed.formattedSpeed))
            } else {
                highlights.append("ai.template.run.highlight.boostLost".localized)
            }
        }

        // Zone highlight
        if session.uniqueZonesVisited > 0 {
            highlights.append(
                "ai.template.run.highlight.newZones".localized(with: "\(session.uniqueZonesVisited)")
            )
        }

        // Anti-farm highlight
        let ratio = session.uniqueZoneRatio
        let ratioText = "\(Int((ratio * 100).rounded()))%"
        if ratio > AppConstants.AntiFarm.highUniqueRatio {
            highlights.append("ai.template.run.highlight.antiFarmHigh".localized(with: ratioText))
        } else if ratio > AppConstants.AntiFarm.mediumUniqueRatio {
            highlights.append("ai.template.run.highlight.antiFarmMedium".localized(with: ratioText))
        } else if session.totalZonesVisited > 0 {
            highlights.append("ai.template.run.highlight.antiFarmLow".localized(with: ratioText))
        }

        // Streak highlight
        if user.streakDays > 0 {
            highlights.append("ai.template.run.highlight.streak".localized(with: "\(user.streakDays)"))
        }

        // Cap highlight
        if trailResult.wasCapped {
            highlights.append("ai.template.run.highlight.runCap".localized)
        } else if trailResult.wasDailyCapped {
            highlights.append("ai.template.run.highlight.dailyCap".localized)
        }

        // Trim to 3-5
        if highlights.count < 3 {
            highlights.append("ai.template.run.highlight.fallback".localized(with: trailText, pointsUnit))
        }
        highlights = Array(highlights.prefix(5))

        // Commentary
        let commentary = buildRunCommentary(
            session: session,
            trailResult: trailResult,
            recentRuns: recentRuns,
            neighborhood: neighborhoodText,
            user: user
        )

        // Next suggestion
        let nextSuggestion = buildRunNextSuggestion(
            session: session,
            trailResult: trailResult
        )

        return AIRunAnalysis(
            runSummary: summary,
            highlights: highlights,
            aiCommentary: commentary,
            nextSuggestion: nextSuggestion
        )
    }

    private static func buildRunCommentary(
        session: RunSession,
        trailResult: TrailCalculator.TrailResult,
        recentRuns: [RunSession],
        neighborhood: String,
        user: User
    ) -> String {
        var parts: [String] = []

        let speedX = String(format: "x%.2f", trailResult.speedMultiplier)
        let durationX = String(format: "x%.2f", trailResult.durationMultiplier)
        let zoneX = String(format: "x%.2f", trailResult.zoneMultiplier)
        parts.append("ai.template.run.commentary.multipliers".localized(with: speedX, durationX, zoneX))

        if !neighborhood.isEmpty {
            parts.append("ai.template.run.commentary.neighborhood".localized(with: neighborhood))
        }

        let priorTrails = recentRuns.filter { $0.id != session.id }.prefix(3).map(\.trail)
        if !priorTrails.isEmpty {
            let avg = priorTrails.reduce(0, +) / Double(priorTrails.count)
            if trailResult.totalTrail > avg * 1.1 {
                parts.append("ai.template.run.commentary.trendUp".localized)
            } else if trailResult.totalTrail < avg * 0.9 {
                parts.append("ai.template.run.commentary.trendDown".localized)
            } else {
                parts.append("ai.template.run.commentary.trendFlat".localized)
            }
        }

        if user.streakDays >= AppConstants.Streak.tier3Days {
            parts.append("ai.template.run.commentary.streakTier3".localized)
        } else if user.streakDays >= AppConstants.Streak.tier2Days {
            parts.append("ai.template.run.commentary.streakTier2".localized)
        } else if user.streakDays >= AppConstants.Streak.tier1Days {
            parts.append("ai.template.run.commentary.streakTier1".localized)
        }

        return parts.joined(separator: " ")
    }

    private static func buildRunNextSuggestion(
        session: RunSession,
        trailResult: TrailCalculator.TrailResult
    ) -> String {
        if session.uniqueZoneRatio < AppConstants.AntiFarm.mediumUniqueRatio,
           session.totalZonesVisited > 0 {
            return "ai.template.run.next.exploreZones".localized
        }

        if session.mode == .boost && !session.isBoostActive {
            return "ai.template.run.next.steadyPace".localized
        }

        if session.mode == .normal && trailResult.speedMultiplier >= 1.4 {
            return "ai.template.run.next.tryBoost".localized
        }

        if trailResult.durationMultiplier < 1.3 {
            return "ai.template.run.next.longerRun".localized
        }

        return "ai.template.run.next.keepStreak".localized
    }

    // MARK: - Weekly

    static func makeWeeklyAnalysis(
        runsThisWeek: [RunSession],
        runsLastWeek: [RunSession],
        user: User
    ) -> AIWeeklyAnalysis {
        let totalDistance = runsThisWeek.reduce(0) { $0 + $1.distance }
        let totalTrail = runsThisWeek.reduce(0) { $0 + $1.trail }
        let lastWeekTrail = runsLastWeek.reduce(0) { $0 + $1.trail }
        let lastWeekDistance = runsLastWeek.reduce(0) { $0 + $1.distance }

        let trailChangePct = lastWeekTrail > 0
            ? Int(((totalTrail - lastWeekTrail) / lastWeekTrail * 100).rounded())
            : 0
        let distanceChangePct = lastWeekDistance > 0
            ? Int(((totalDistance - lastWeekDistance) / lastWeekDistance * 100).rounded())
            : 0

        let totalDistanceText = (totalDistance / 1000.0).formattedDistance
        let totalTrailText = totalTrail.formattedTrail
        let pointsUnit = "trail.unit".localized

        // Trend
        let trend: String
        if lastWeekTrail == 0 {
            trend = "ai.template.week.trend.firstWeek".localized(with: "\(runsThisWeek.count)", totalTrailText, pointsUnit)
        } else if trailChangePct > 5 {
            trend = "ai.template.week.trend.up".localized(with: "\(abs(trailChangePct))", totalTrailText, pointsUnit)
        } else if trailChangePct < -5 {
            trend = "ai.template.week.trend.down".localized(with: "\(abs(trailChangePct))", totalTrailText, pointsUnit)
        } else {
            trend = "ai.template.week.trend.flat".localized(with: totalTrailText, pointsUnit)
        }

        // Top achievement
        let topAchievement: String
        if let bestRun = runsThisWeek.max(by: { $0.trail < $1.trail }), bestRun.trail > 0 {
            topAchievement = "ai.template.week.top.bestRun".localized(
                with: bestRun.trail.formattedTrail,
                pointsUnit,
                (bestRun.distance / 1000.0).formattedDistance
            )
        } else if user.streakDays >= AppConstants.Streak.tier1Days {
            topAchievement = "ai.template.week.top.streak".localized(with: "\(user.streakDays)")
        } else {
            topAchievement = "ai.template.week.top.fallback".localized(
                with: "\(runsThisWeek.count)",
                totalDistanceText
            )
        }

        // Weak point
        let totalZones = runsThisWeek.reduce(0) { $0 + $1.totalZonesVisited }
        let uniqueZones = runsThisWeek.reduce(0) { $0 + $1.uniqueZonesVisited }
        let ratio = totalZones > 0 ? Double(uniqueZones) / Double(totalZones) : 1.0
        let boostRuns = runsThisWeek.filter { $0.mode == .boost }
        let boostKept = boostRuns.filter { $0.isBoostActive }
        let weakPoint: String
        if ratio <= AppConstants.AntiFarm.mediumUniqueRatio && totalZones > 0 {
            weakPoint = "ai.template.week.weak.antiFarm".localized(with: "\(Int((ratio * 100).rounded()))")
        } else if !boostRuns.isEmpty && boostKept.count < boostRuns.count {
            weakPoint = "ai.template.week.weak.boostLost".localized(
                with: "\(boostRuns.count - boostKept.count)",
                "\(boostRuns.count)"
            )
        } else if runsThisWeek.count <= 2 {
            weakPoint = "ai.template.week.weak.fewRuns".localized(with: "\(runsThisWeek.count)")
        } else {
            weakPoint = "ai.template.week.weak.fallback".localized
        }

        // Next week focus
        let nextWeekFocus: String
        if user.streakDays < AppConstants.Streak.tier1Days {
            nextWeekFocus = "ai.template.week.focus.streak".localized
        } else if ratio <= AppConstants.AntiFarm.highUniqueRatio {
            nextWeekFocus = "ai.template.week.focus.exploration".localized
        } else if distanceChangePct < 0 {
            nextWeekFocus = "ai.template.week.focus.distance".localized
        } else {
            nextWeekFocus = "ai.template.week.focus.consolidate".localized(with: pointsUnit)
        }

        return AIWeeklyAnalysis(
            weekTrend: trend,
            topAchievement: topAchievement,
            weakPoint: weakPoint,
            nextWeekFocus: nextWeekFocus
        )
    }

    // MARK: - Helpers

    private static func formattedDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
