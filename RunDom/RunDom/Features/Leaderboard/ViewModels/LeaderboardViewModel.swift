import SwiftUI

@MainActor
final class LeaderboardViewModel: ObservableObject {

    // MARK: - Published State

    @Published var scope: LeaderboardScope = .global
    @Published var entries: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Services

    private let locationManager: LocationManager
    private let firestoreService: FirestoreService
    private let geocodingService: GeocodingService

    // MARK: - Init

    init(
        locationManager: LocationManager,
        firestoreService: FirestoreService = FirestoreService(),
        geocodingService: GeocodingService = .shared
    ) {
        self.locationManager = locationManager
        self.firestoreService = firestoreService
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

            let neighborhood = scope == .neighborhood ? await resolveNeighborhood(for: currentUser) : nil

            entries = try await firestoreService.getLeaderboard(
                scope: scope,
                seasonId: seasonId,
                neighborhood: neighborhood
            )
        } catch {
            AppLogger.firebase.error("Failed to load leaderboard: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }

        isLoading = false
    }

    func switchScope(to newScope: LeaderboardScope, currentUser: User? = nil) async {
        scope = newScope
        await loadLeaderboard(currentUser: currentUser)
    }

    private func resolveNeighborhood(for currentUser: User?) async -> String? {
        if let currentNeighborhood = currentUser?.neighborhood?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !currentNeighborhood.isEmpty {
            return currentNeighborhood
        }

        guard let coordinate = locationManager.currentLocation?.coordinate ?? locationManager.lastKnownCoordinate,
            let geocoded = await geocodingService.neighborhoodName(for: coordinate)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !geocoded.isEmpty
        else {
            return nil
        }

        if let userId = currentUser?.id {
            do {
                try await firestoreService.updateUserNeighborhood(userId: userId, neighborhood: geocoded)
            } catch {
                AppLogger.firebase.warning("Failed to persist user neighborhood: \(error.localizedDescription)")
            }
        }

        return geocoded
    }
}
