import SwiftUI

@MainActor
final class BadgeViewModel: ObservableObject {

    // MARK: - Published State

    @Published var badge: Badge?
    @Published var isLoading = false

    // MARK: - Services

    private let firestoreService: FirestoreService

    // MARK: - Init

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
    }

    // MARK: - Computed

    var categoryDisplayName: String {
        guard let badge else { return "" }
        return "badge.category.\(badge.category.rawValue)".localized
    }

    var progressText: String {
        guard let badge else { return "" }
        let current = Int(badge.progress)
        let target = Int(badge.targetValue)
        return "\(current) / \(target)"
    }

    var unlockedDateText: String? {
        guard let date = badge?.unlockedAt else { return nil }
        return date.formatted(style: .medium)
    }

    // MARK: - Loading

    func loadBadge(badgeId: String, userId: String) async {
        isLoading = true
        do {
            let badges = try await firestoreService.getBadges(userId: userId)
            badge = badges.first { $0.id == badgeId }
        } catch {
            AppLogger.firebase.error("Failed to load badge: \(error.localizedDescription)")
        }
        isLoading = false
    }
}
