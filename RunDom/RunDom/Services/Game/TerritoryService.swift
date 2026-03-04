import Foundation
import CoreLocation

/// Manages territory capture, defense levels, and decay mechanics.
final class TerritoryService {

    // MARK: - Services

    private let realtimeDB: RealtimeDBService
    private let h3Service: H3GridService
    private let seasonService: SeasonService

    init(
        realtimeDB: RealtimeDBService = RealtimeDBService(),
        h3Service: H3GridService = .shared,
        seasonService: SeasonService = SeasonService()
    ) {
        self.realtimeDB = realtimeDB
        self.h3Service = h3Service
        self.seasonService = seasonService
    }

    // MARK: - Capture Result

    struct CaptureResult {
        let h3Index: String
        let captured: Bool
        let isNewTerritory: Bool
        let previousOwnerId: String?
    }

    // MARK: - Territory Capture

    /// Captures territories along a route during a run.
    /// Returns the list of capture results for each unique zone visited.
    func captureTerritoriesAlongRoute(
        route: [RoutePoint],
        userId: String,
        userColor: String
    ) async throws -> [CaptureResult] {
        let season = try await seasonService.getOrCreateCurrentSeason()
        let coveredCells = h3Service.coveredCells(along: route)

        var results: [CaptureResult] = []

        for cellIndex in coveredCells {
            // Calculate distance run in this cell
            let cellDistance = distanceInCell(cellIndex: cellIndex, route: route)
            guard cellDistance > 0 else { continue }

            let existingTerritory = try await realtimeDB.getTerritory(
                seasonId: season.id,
                h3Index: cellIndex
            )

            let isNewTerritory = existingTerritory == nil
            let previousOwnerId = existingTerritory?.ownerId

            let captured = try await realtimeDB.captureTerritory(
                seasonId: season.id,
                h3Index: cellIndex,
                userId: userId,
                userColor: userColor,
                distance: cellDistance
            )

            results.append(CaptureResult(
                h3Index: cellIndex,
                captured: captured,
                isNewTerritory: isNewTerritory,
                previousOwnerId: previousOwnerId
            ))
        }

        let capturedCount = results.filter(\.captured).count
        AppLogger.game.info("Territory capture: \(capturedCount)/\(results.count) zones captured by \(userId)")

        return results
    }

    // MARK: - Single Territory Capture

    /// Captures a single territory cell (used during live run tracking).
    func captureTerritory(
        h3Index: String,
        userId: String,
        userColor: String,
        distance: Double,
        seasonId: String
    ) async throws -> Bool {
        try await realtimeDB.captureTerritory(
            seasonId: seasonId,
            h3Index: h3Index,
            userId: userId,
            userColor: userColor,
            distance: distance
        )
    }

    // MARK: - Defense Level

    /// Returns the effective defense level after applying decay.
    func effectiveDefenseLevel(for territory: Territory) -> Double {
        territory.decayedDefenseLevel
    }

    /// Checks if a territory can be captured by calculating if attacker distance
    /// would reduce defense to zero.
    func canCapture(territory: Territory, attackerDistance: Double) -> Bool {
        let effectiveDefense = effectiveDefenseLevel(for: territory)
        return attackerDistance >= effectiveDefense
    }

    // MARK: - User Territories

    /// Returns all territories owned by a user in the current season.
    func getUserTerritories(userId: String) async throws -> [Territory] {
        let season = try await seasonService.getOrCreateCurrentSeason()
        return try await realtimeDB.getUserTerritories(seasonId: season.id, userId: userId)
    }

    /// Returns count of territories owned by user.
    func getUserTerritoryCount(userId: String) async throws -> Int {
        let territories = try await getUserTerritories(userId: userId)
        return territories.count
    }

    // MARK: - Territory Info

    /// Gets a single territory by H3 index.
    func getTerritory(h3Index: String) async throws -> Territory? {
        let season = try await seasonService.getOrCreateCurrentSeason()
        return try await realtimeDB.getTerritory(seasonId: season.id, h3Index: h3Index)
    }

    // MARK: - Private Helpers

    /// Calculates the approximate distance a user ran within a specific H3 cell.
    private func distanceInCell(cellIndex: String, route: [RoutePoint]) -> Double {
        var totalDistance: Double = 0
        var previousPoint: RoutePoint?

        for point in route {
            let pointIndex = h3Service.h3Index(for: point.coordinate)
            if pointIndex == cellIndex {
                if let prev = previousPoint {
                    totalDistance += prev.coordinate.distance(to: point.coordinate)
                }
                previousPoint = point
            } else {
                previousPoint = nil
            }
        }

        return totalDistance
    }
}
