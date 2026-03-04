import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Published State

    @Published var user: User?
    @Published var badges: [Badge] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Services

    private let firestoreService: FirestoreService
    private let storageService: StorageService

    // MARK: - Init

    init(firestoreService: FirestoreService = FirestoreService(),
         storageService: StorageService = StorageService()) {
        self.firestoreService = firestoreService
        self.storageService = storageService
    }

    // MARK: - Computed

    var unlockedBadges: [Badge] {
        badges.filter { $0.isUnlocked }
    }

    var lockedBadges: [Badge] {
        badges.filter { !$0.isUnlocked && !$0.isSecret }
    }

    var streakText: String {
        guard let user else { return "" }
        return String(format: "profile.streakDays".localized, user.streakDays)
    }

    // MARK: - Data Loading

    func loadProfile(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            async let userTask = firestoreService.getUser(id: userId)
            async let badgesTask = firestoreService.getBadges(userId: userId)

            let (fetchedUser, fetchedBadges) = try await (userTask, badgesTask)
            user = fetchedUser
            badges = fetchedBadges
        } catch {
            AppLogger.firebase.error("Failed to load profile: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }

        isLoading = false
    }

    func refreshUser(userId: String) async {
        do {
            user = try await firestoreService.getUser(id: userId)
        } catch {
            AppLogger.firebase.error("Failed to refresh user: \(error.localizedDescription)")
        }
    }
}
