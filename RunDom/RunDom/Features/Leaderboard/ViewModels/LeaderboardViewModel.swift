import SwiftUI

@MainActor
final class LeaderboardViewModel: ObservableObject {

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

            let neighborhood = scope == .neighborhood ? await resolveNeighborhood(for: currentUser) : nil

            entries = try await firestoreService.getLeaderboard(
                scope: scope,
                period: period,
                seasonId: seasonId,
                neighborhood: neighborhood
            )
            if let currentUserId = currentUser?.id {
                currentUserEntry = try await firestoreService.getCurrentUserLeaderboardEntry(
                    userId: currentUserId,
                    scope: scope,
                    period: period,
                    seasonId: seasonId,
                    neighborhood: neighborhood
                )
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

    func switchScope(to newScope: LeaderboardScope, currentUser: User? = nil) async {
        scope = newScope
        await loadLeaderboard(currentUser: currentUser)
    }

    func switchPeriod(to newPeriod: LeaderboardPeriod, currentUser: User? = nil) async {
        period = newPeriod
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
