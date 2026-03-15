import Foundation
import CoreLocation
import CoreMotion

/// Detects cheating attempts: GPS spoofing, speed anomalies, and farming patterns.
final class AntiCheatService {

    // MARK: - Validation Result

    struct ValidationResult {
        let isValid: Bool
        let flags: [CheatFlag]
    }

    enum CheatFlag: String {
        case speedTooLow = "speed_too_low"
        case speedTooHigh = "speed_too_high"
        case gpsAnomaly = "gps_anomaly"
        case noMotionData = "no_motion_data"
        case motionSpeedMismatch = "motion_speed_mismatch"
        case farmingDetected = "farming_detected"
        case circularRoute = "circular_route"
    }

    // MARK: - Speed Validation

    /// Validates that speed is within reasonable bounds for a runner.
    func validateSpeed(_ speedKmh: Double) -> [CheatFlag] {
        var flags: [CheatFlag] = []

        if speedKmh < AppConstants.Game.minSpeedKmh && speedKmh > 0 {
            flags.append(.speedTooLow)
        }

        // 50 km/h is well beyond any human running speed
        if speedKmh > 50 {
            flags.append(.speedTooHigh)
        }

        return flags
    }

    // MARK: - GPS Anomaly Detection

    /// Detects GPS teleportation: impossibly large jumps between consecutive points.
    func validateGPSConsistency(previous: RoutePoint, current: RoutePoint) -> [CheatFlag] {
        var flags: [CheatFlag] = []

        let timeDelta = current.timestamp.timeIntervalSince(previous.timestamp)
        guard timeDelta > 0 else { return flags }

        let distance = previous.coordinate.distance(to: current.coordinate)
        let impliedSpeedMps = distance / timeDelta

        // If implied speed exceeds 30 m/s (~108 km/h), it's anomalous
        if impliedSpeedMps > 30 {
            flags.append(.gpsAnomaly)
            AppLogger.game.warning("GPS anomaly: \(impliedSpeedMps) m/s between points")
        }

        return flags
    }

    // MARK: - Motion Cross-Validation

    /// Validates GPS speed against accelerometer data to detect spoofing.
    /// If device reports no significant motion but GPS shows movement, flag it.
    func validateMotionConsistency(
        gpsSpeedMps: Double,
        accelerometerMagnitude: Double,
        isDeviceStationary: Bool
    ) -> [CheatFlag] {
        var flags: [CheatFlag] = []

        // If GPS says moving fast but device is stationary
        if gpsSpeedMps > 2.0 && isDeviceStationary {
            flags.append(.motionSpeedMismatch)
            AppLogger.game.warning("Motion mismatch: GPS=\(gpsSpeedMps) m/s but device stationary")
        }

        // If GPS says running speed but accelerometer shows no bounce pattern
        if gpsSpeedMps > 3.0 && accelerometerMagnitude < 0.3 {
            flags.append(.motionSpeedMismatch)
        }

        return flags
    }

    // MARK: - Farming Detection

    /// Detects small-area farming by analyzing the unique zone ratio.
    func validateFarmingPattern(uniqueZonesVisited: Int, totalZonesVisited: Int) -> [CheatFlag] {
        guard totalZonesVisited > 5 else { return [] }

        let ratio = Double(uniqueZonesVisited) / Double(totalZonesVisited)
        if ratio < AppConstants.AntiFarm.mediumUniqueRatio {
            AppLogger.game.warning("Farming detected: unique ratio=\(ratio)")
            return [.farmingDetected]
        }

        return []
    }

    /// Detects circular running patterns by checking if the user keeps revisiting the same zones.
    func validateCircularRoute(visitedZones: [String]) -> [CheatFlag] {
        guard visitedZones.count > 10 else { return [] }

        var zoneCounts: [String: Int] = [:]
        for zone in visitedZones {
            zoneCounts[zone, default: 0] += 1
        }

        // If any single zone is visited more than 30% of total visits, it's circular
        let maxVisits = zoneCounts.values.max() ?? 0
        let ratio = Double(maxVisits) / Double(visitedZones.count)

        if ratio > 0.3 {
            AppLogger.game.warning("Circular route detected: max zone ratio=\(ratio)")
            return [.circularRoute]
        }

        return []
    }

    // MARK: - Full Route Validation

    /// Performs all validations on a completed route.
    func validateRoute(points: [RoutePoint], visitedZones: [String]) -> ValidationResult {
        var allFlags: [CheatFlag] = []

        // Speed check on average
        let avgSpeed = points.reduce(0.0) { $0 + $1.speedKmh } / max(Double(points.count), 1)
        allFlags.append(contentsOf: validateSpeed(avgSpeed))

        // GPS consistency check between consecutive points.
        // Using zip avoids invalid ranges for empty/single-point runs.
        for (previous, current) in zip(points, points.dropFirst()) {
            let gpsFlags = validateGPSConsistency(previous: previous, current: current)
            allFlags.append(contentsOf: gpsFlags)
        }

        // Farming pattern check
        let uniqueZones = Set(visitedZones).count
        allFlags.append(contentsOf: validateFarmingPattern(
            uniqueZonesVisited: uniqueZones,
            totalZonesVisited: visitedZones.count
        ))

        // Circular route check
        allFlags.append(contentsOf: validateCircularRoute(visitedZones: visitedZones))

        let criticalFlags: Set<CheatFlag> = [.gpsAnomaly, .speedTooHigh]
        let hasCritical = allFlags.contains(where: { criticalFlags.contains($0) })

        return ValidationResult(isValid: !hasCritical, flags: allFlags)
    }

    // MARK: - Boost Speed Validation

    /// Checks if the current speed is above the boost threshold.
    func isBoostSpeedMet(currentSpeedKmh: Double) -> Bool {
        currentSpeedKmh >= AppConstants.Game.boostMinSpeedKmh
    }

    /// Determines if boost should be cancelled based on average speed.
    func shouldCancelBoost(avgSpeedKmh: Double) -> Bool {
        avgSpeedKmh < AppConstants.Game.boostMinSpeedKmh
    }
}
