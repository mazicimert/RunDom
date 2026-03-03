import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published State

    @Published var isAuthenticated = false
    @Published var isOnboardingComplete: Bool
    @Published var currentUser: User?
    @Published var isLoading = true

    // MARK: - Services

    let authService: AuthService
    let firestoreService: FirestoreService

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        self.authService = AuthService()
        self.firestoreService = FirestoreService()
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
            if let user = try await firestoreService.getUser(id: firebaseUser.uid) {
                currentUser = user
            } else {
                // First-time sign in — create user document
                let newUser = User(
                    id: firebaseUser.uid,
                    displayName: firebaseUser.displayName ?? "runner.defaultName".localized,
                    email: firebaseUser.email ?? "",
                    color: Self.randomUserColor()
                )
                try await firestoreService.createUser(newUser)
                currentUser = newUser
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

    // MARK: - Helpers

    private static func randomUserColor() -> String {
        let colors = [
            "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
            "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F",
            "#BB8FCE", "#85C1E9", "#F0B27A", "#82E0AA"
        ]
        return colors.randomElement() ?? "#4ECDC4"
    }
}
