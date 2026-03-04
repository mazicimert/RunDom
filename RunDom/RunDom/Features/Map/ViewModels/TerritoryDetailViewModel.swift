import SwiftUI

@MainActor
final class TerritoryDetailViewModel: ObservableObject {

    // MARK: - Published State

    @Published var territory: Territory
    @Published var ownerName: String = ""
    @Published var isCurrentUser = false

    // MARK: - Services

    private let firestoreService = FirestoreService()

    // MARK: - Init

    init(territory: Territory, currentUserId: String?) {
        self.territory = territory
        self.isCurrentUser = territory.ownerId == currentUserId
        self.ownerName = isCurrentUser ? "map.myTerritory".localized : territory.ownerId
        if !isCurrentUser {
            Task { await loadOwnerName() }
        }
    }

    // MARK: - Data Loading

    private func loadOwnerName() async {
        do {
            if let user = try await firestoreService.getUser(id: territory.ownerId) {
                ownerName = user.displayName
            }
        } catch {
            AppLogger.firebase.error("Failed to load territory owner: \(error.localizedDescription)")
        }
    }

    // MARK: - Computed

    var defensePercentage: Double {
        min(territory.decayedDefenseLevel / 100.0, 1.0)
    }

    var defenseColor: Color {
        if territory.isDecaying {
            return .orange
        }
        if defensePercentage > 0.6 {
            return .green
        } else if defensePercentage > 0.3 {
            return .yellow
        }
        return .red
    }

    var ownerColor: Color {
        Color(hex: territory.ownerColor) ?? .blue
    }

    var lastActiveText: String {
        territory.lastRunDate.relativeFormatted()
    }

    var totalDistanceText: String {
        territory.totalDistance.formattedDistance
    }
}
