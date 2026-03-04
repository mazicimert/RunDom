import SwiftUI

@MainActor
final class LeaderboardViewModel: ObservableObject {

    // MARK: - Published State

    @Published var scope: LeaderboardScope = .global
    @Published var entries: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Services

    private let firestoreService: FirestoreService

    // MARK: - Init

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
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

    func loadLeaderboard(currentUserNeighborhood: String? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            let season = try await firestoreService.getCurrentSeason()
            let seasonId = season?.id ?? ""

            entries = try await firestoreService.getLeaderboard(
                scope: scope,
                seasonId: seasonId,
                neighborhood: scope == .neighborhood ? currentUserNeighborhood : nil
            )
        } catch {
            AppLogger.firebase.error("Failed to load leaderboard: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }

        isLoading = false
    }

    func switchScope(to newScope: LeaderboardScope, neighborhood: String? = nil) async {
        scope = newScope
        await loadLeaderboard(currentUserNeighborhood: neighborhood)
    }
}
