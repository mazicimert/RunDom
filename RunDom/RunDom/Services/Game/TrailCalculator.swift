import Foundation

/// Calculates Trail (İz) points earned from a run session.
///
/// Formula: Trail = (Base × Speed × Duration × Zone) × Streak × Mode × Anti-Farm
/// - Base: distance(km) × 100
/// - Speed: min(avgSpeed / 10, 1.8) — min threshold 6 km/h, cap at 18 km/h
/// - Duration: min(1.0 + (minutes / 100), 2.0) — caps at 120 min
/// - Zone: min(1.0 + (newZones × 0.1), 2.0) — caps at 10+ new zones
/// - Streak: 3d→x1.2, 7d→x1.5, 14d→x2.0
/// - Mode: Normal=x1.0, Boost=x2.0 (drops to x1.0 if avg < 7 km/h)
/// - Anti-Farm: unique >70%→x1.0, 40-70%→x0.7, <40%→x0.4
/// - Caps: Max 5,000 per run, 15,000 per day
final class TrailCalculator {

    // MARK: - Input

    struct RunInput {
        let distanceKm: Double
        let avgSpeedKmh: Double
        let durationMinutes: Double
        let newZonesCount: Int
        let uniqueZoneRatio: Double
        let streakDays: Int
        let mode: RunMode
        let isBoostActive: Bool
        let hasDropzoneBoost: Bool
        let todayTrail: Double
    }

    // MARK: - Output

    struct TrailResult {
        let totalTrail: Double
        let basePoints: Double
        let speedMultiplier: Double
        let durationMultiplier: Double
        let zoneMultiplier: Double
        let streakMultiplier: Double
        let modeMultiplier: Double
        let antiFarmMultiplier: Double
        let dropzoneMultiplier: Double
        let wasCapped: Bool
        let wasDailyCapped: Bool
    }

    // MARK: - Calculation

    func calculate(input: RunInput) -> TrailResult {
        let base = basePoints(distanceKm: input.distanceKm)
        let speed = speedMultiplier(avgSpeedKmh: input.avgSpeedKmh)
        let duration = durationMultiplier(minutes: input.durationMinutes)
        let zone = zoneMultiplier(newZones: input.newZonesCount)
        let streak = streakMultiplier(days: input.streakDays)
        let mode = modeMultiplier(mode: input.mode, isBoostActive: input.isBoostActive)
        let antiFarm = antiFarmMultiplier(uniqueRatio: input.uniqueZoneRatio)
        let dropzone = input.hasDropzoneBoost ? AppConstants.Game.dropzoneRewardMultiplier : 1.0

        var trail = (base * speed * duration * zone) * streak * mode * antiFarm * dropzone

        // Per-run cap
        let wasCapped = trail > AppConstants.Game.maxTrailPerRun
        trail = min(trail, AppConstants.Game.maxTrailPerRun)

        // Daily cap
        let remainingDaily = max(AppConstants.Game.maxTrailPerDay - input.todayTrail, 0)
        let wasDailyCapped = trail > remainingDaily
        trail = min(trail, remainingDaily)

        return TrailResult(
            totalTrail: trail,
            basePoints: base,
            speedMultiplier: speed,
            durationMultiplier: duration,
            zoneMultiplier: zone,
            streakMultiplier: streak,
            modeMultiplier: mode,
            antiFarmMultiplier: antiFarm,
            dropzoneMultiplier: dropzone,
            wasCapped: wasCapped,
            wasDailyCapped: wasDailyCapped
        )
    }

    /// Convenience method that builds input from a RunSession + user state.
    func calculate(
        session: RunSession,
        streakDays: Int,
        hasDropzoneBoost: Bool,
        todayTrail: Double
    ) -> TrailResult {
        let input = RunInput(
            distanceKm: session.distance / 1000.0,
            avgSpeedKmh: session.avgSpeed,
            durationMinutes: session.durationMinutes,
            newZonesCount: session.uniqueZonesVisited,
            uniqueZoneRatio: session.uniqueZoneRatio,
            streakDays: streakDays,
            mode: session.mode,
            isBoostActive: session.isBoostActive,
            hasDropzoneBoost: hasDropzoneBoost,
            todayTrail: todayTrail
        )
        return calculate(input: input)
    }

    // MARK: - Individual Multipliers

    func basePoints(distanceKm: Double) -> Double {
        distanceKm * AppConstants.Game.basePointMultiplier
    }

    func speedMultiplier(avgSpeedKmh: Double) -> Double {
        guard avgSpeedKmh >= AppConstants.Game.minSpeedKmh else { return 0 }
        return min(avgSpeedKmh / AppConstants.Game.speedDivisor, AppConstants.Game.maxSpeedMultiplier)
    }

    func durationMultiplier(minutes: Double) -> Double {
        let clampedMinutes = min(minutes, AppConstants.Game.maxDurationMinutes)
        return min(1.0 + (clampedMinutes / AppConstants.Game.durationDivisor), AppConstants.Game.maxDurationMultiplier)
    }

    func zoneMultiplier(newZones: Int) -> Double {
        min(1.0 + (Double(newZones) * AppConstants.Game.zoneMultiplierStep), AppConstants.Game.maxZoneMultiplier)
    }

    func streakMultiplier(days: Int) -> Double {
        if days >= AppConstants.Streak.tier3Days {
            return AppConstants.Streak.tier3Multiplier
        } else if days >= AppConstants.Streak.tier2Days {
            return AppConstants.Streak.tier2Multiplier
        } else if days >= AppConstants.Streak.tier1Days {
            return AppConstants.Streak.tier1Multiplier
        }
        return AppConstants.Streak.noStreakMultiplier
    }

    func modeMultiplier(mode: RunMode, isBoostActive: Bool) -> Double {
        switch mode {
        case .normal:
            return 1.0
        case .boost:
            return isBoostActive ? AppConstants.Game.boostModeMultiplier : 1.0
        }
    }

    func antiFarmMultiplier(uniqueRatio: Double) -> Double {
        if uniqueRatio > AppConstants.AntiFarm.highUniqueRatio {
            return AppConstants.AntiFarm.highMultiplier
        } else if uniqueRatio > AppConstants.AntiFarm.mediumUniqueRatio {
            return AppConstants.AntiFarm.mediumMultiplier
        }
        return AppConstants.AntiFarm.lowMultiplier
    }
}
