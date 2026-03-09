import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published State

    @Published var isAuthenticated = false
    @Published var isOnboardingComplete: Bool
    @Published var currentUser: User?
    @Published var isLoading = true
    @Published var requiresProfileCompletion = false

    // MARK: - Services

    let authService: AuthService
    let firestoreService: FirestoreService
    let locationManager: LocationManager

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        self.authService = AuthService()
        self.firestoreService = FirestoreService()
        self.locationManager = LocationManager()
        self.isOnboardingComplete = UserDefaults.standard.bool(
            forKey: AppConstants.UserDefaultsKeys.isOnboardingComplete
        )

        observeAuthState()
    }

    // MARK: - Auth Observation

    private func observeAuthState() {
        authService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuth in
                guard let self else { return }
                self.isAuthenticated = isAuth
                if isAuth {
                    Task { await self.loadCurrentUser() }
                } else {
                    self.currentUser = nil
                    self.isLoading = false
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - User Loading

    func loadCurrentUser() async {
        guard let firebaseUser = authService.currentUser else {
            isLoading = false
            return
        }

        do {
            if var user = try await firestoreService.getUser(id: firebaseUser.uid) {
                // Sync displayName from Firebase Auth if it changed
                if let authDisplayName = firebaseUser.displayName,
                   !authDisplayName.isEmpty,
                   authDisplayName != user.displayName,
                   !Self.isDefaultDisplayName(authDisplayName) {
                    user.displayName = authDisplayName
                    try await firestoreService.updateUser(user)
                }
                currentUser = user
                requiresProfileCompletion = Self.isDefaultDisplayName(user.displayName)
            } else {
                // First-time sign in — create user document
                let displayName = firebaseUser.displayName ?? ""
                let needsCompletion = displayName.isEmpty || Self.isDefaultDisplayName(displayName)
                let newUser = User(
                    id: firebaseUser.uid,
                    displayName: displayName.isEmpty ? "runner.defaultName".localized : displayName,
                    email: firebaseUser.email ?? "",
                    color: Self.randomUserColor()
                )
                try await firestoreService.createUser(newUser)
                currentUser = newUser
                requiresProfileCompletion = needsCompletion
            }
        } catch {
            AppLogger.firebase.error("Failed to load user: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isOnboardingComplete)
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try authService.signOut()
            currentUser = nil
        } catch {
            AppLogger.auth.error("Sign out failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Profile Completion

    func completeProfile(displayName: String) async {
        guard var user = currentUser else { return }
        user.displayName = displayName
        do {
            try await firestoreService.updateUser(user)
            currentUser = user
            requiresProfileCompletion = false
        } catch {
            AppLogger.firebase.error("Failed to update profile: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private static func isDefaultDisplayName(_ name: String) -> Bool {
        let defaults = ["runner.defaultName".localized, "Runner", "Koşucu"]
        return defaults.contains(name)
    }

    private static func randomUserColor() -> String {
        let colors = [
            "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
            "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F",
            "#BB8FCE", "#85C1E9", "#F0B27A", "#82E0AA"
        ]
        return colors.randomElement() ?? "#4ECDC4"
    }
}
