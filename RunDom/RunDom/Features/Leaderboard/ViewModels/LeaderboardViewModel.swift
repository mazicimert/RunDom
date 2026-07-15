import SwiftUI

@MainActor
final class LeaderboardViewModel: ObservableObject {

    private struct AreaContext {
        let neighborhood: String?
        let areaId: String?
    }

    // MARK: - Published State

    @Published var scope: LeaderboardScope = .global
    @Published var period: LeaderboardPeriod = .weekly
    @Published var entries: [LeaderboardEntry] = []
    @Published var currentUserEntry: LeaderboardEntry?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Services

    private let locationManager: LocationManager
    private let firestoreService: FirestoreService
    private let realtimeDB: RealtimeDBService
    private let geocodingService: GeocodingService

    // MARK: - Init

    init(
        locationManager: LocationManager,
        firestoreService: FirestoreService = FirestoreService(),
        realtimeDB: RealtimeDBService = RealtimeDBService(),
        geocodingService: GeocodingService = .shared
    ) {
        self.locationManager = locationManager
        self.firestoreService = firestoreService
        self.realtimeDB = realtimeDB
        self.geocodingService = geocodingService
    }

    // MARK: - Computed

    var podiumEntries: [LeaderboardEntry] {
        Array(entries.prefix(3))
    }

    var remainingEntries: [LeaderboardEntry] {
        Array(entries.dropFirst(3))
    }

    var isEmpty: Bool {
        entries.isEmpty && !isLoading
    }

    var contextTitle: String {
        switch period {
        case .weekly:
            return "leaderboard.period.weekly".localized
        case .allTime:
            return "leaderboard.period.allTime".localized
        }
    }

    var contextSubtitle: String {
        let scopeTitle = scope == .global
            ? "leaderboard.global".localized
            : "leaderboard.neighborhood".localized
        return "leaderboard.context.subtitle".localized(with: contextTitle, scopeTitle)
    }

    var contextHeadline: String {
        contextSubtitle
    }

    var contextDescription: String {
        switch (period, scope) {
        case (.weekly, .global):
            return "leaderboard.context.description.weeklyGlobal".localized
        case (.weekly, .neighborhood):
            return "leaderboard.context.description.weeklyNeighborhood".localized
        case (.allTime, .global):
            return "leaderboard.context.description.allTimeGlobal".localized
        case (.allTime, .neighborhood):
            return "leaderboard.context.description.allTimeNeighborhood".localized
        }
    }

    // MARK: - Data Loading

    func loadLeaderboard(currentUser: User? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            let seasonId: String
            do {
                seasonId = try await firestoreService.getCurrentSeason()?.id ?? ""
            } catch {
                AppLogger.firebase.warning("Failed to fetch current season for leaderboard, using fallback: \(error.localizedDescription)")
                seasonId = ""
            }

            let areaContext = scope == .neighborhood ? await resolveAreaContext(for: currentUser) : nil

            let loadedEntries = try await firestoreService.getLeaderboard(
                scope: scope,
                period: period,
                seasonId: seasonId,
                neighborhood: areaContext?.neighborhood,
                areaId: areaContext?.areaId
            )
            let territoryCounts = await loadTerritoryCounts(seasonId: loadedEntries.first?.seasonId ?? seasonId)
            entries = loadedEntries.map {
                $0.withTerritoriesOwned(territoryCounts[$0.userId, default: 0])
            }
            if let currentUserId = currentUser?.id {
                let loadedCurrentUserEntry = try await firestoreService.getCurrentUserLeaderboardEntry(
                    userId: currentUserId,
                    scope: scope,
                    period: period,
                    seasonId: seasonId,
                    neighborhood: areaContext?.neighborhood,
                    areaId: areaContext?.areaId
                )
                currentUserEntry = loadedCurrentUserEntry.map {
                    $0.withTerritoriesOwned(territoryCounts[$0.userId, default: 0])
                }
            } else {
                currentUserEntry = nil
            }
        } catch {
            AppLogger.firebase.error("Failed to load leaderboard: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
            currentUserEntry = nil
        }

        isLoading = false
    }

    private func loadTerritoryCounts(seasonId: String) async -> [String: Int] {
        guard !seasonId.isEmpty else { return [:] }
        do {
            let territories = try await realtimeDB.getTerritories(seasonId: seasonId)
            return territories.reduce(into: [:]) { counts, territory in
                counts[territory.ownerId, default: 0] += 1
            }
        } catch {
            AppLogger.firebase.warning("Failed to load leaderboard territory counts: \(error.localizedDescription)")
            return [:]
        }
    }

    func switchScope(to newScope: LeaderboardScope, currentUser: User? = nil) async {
        scope = newScope
        await loadLeaderboard(currentUser: currentUser)
    }

    func switchPeriod(to newPeriod: LeaderboardPeriod, currentUser: User? = nil) async {
        period = newPeriod
        await loadLeaderboard(currentUser: currentUser)
    }

    private func resolveAreaContext(for currentUser: User?) async -> AreaContext? {
        let storedNeighborhood = currentUser?.neighborhood?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let storedAreaId = currentUser?.areaId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !storedAreaId.isEmpty {
            return AreaContext(neighborhood: storedNeighborhood, areaId: storedAreaId)
        }

        guard let coordinate = locationManager.currentLocation?.coordinate ?? locationManager.lastKnownCoordinate,
              let identity = await geocodingService.areaIdentity(for: coordinate)
        else {
            return storedNeighborhood.map { AreaContext(neighborhood: $0, areaId: nil) }
        }

        if let userId = currentUser?.id {
            do {
                try await firestoreService.updateUserNeighborhood(
                    userId: userId,
                    neighborhood: identity.displayName,
                    areaId: identity.areaId
                )
            } catch {
                AppLogger.firebase.warning("Failed to persist user neighborhood: \(error.localizedDescription)")
            }
        }

        return AreaContext(neighborhood: identity.displayName, areaId: identity.areaId)
    }
}
