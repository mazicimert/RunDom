import SwiftUI
import Combine
import FirebaseMessaging

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published State

    @Published var isAuthenticated = false
    @Published var isOnboardingComplete: Bool
    @Published var currentUser: User?
    @Published var isLoading = true
    @Published var requiresProfileCompletion = false
    @Published var shouldShowWelcome = false

    // MARK: - Services

    let authService: AuthService
    let firestoreService: FirestoreService
    let messagingService: MessagingService
    let locationManager: LocationManager
    let badgeService: BadgeService

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        self.authService = AuthService()
        self.firestoreService = FirestoreService()
        self.messagingService = MessagingService()
        self.locationManager = LocationManager()
        self.badgeService = BadgeService()
        self.isOnboardingComplete = UserDefaults.standard.bool(
            forKey: AppConstants.UserDefaultsKeys.isOnboardingComplete
        )

        observeAuthState()
        observeFCMToken()
        observeLanguageChanges()
    }

    private func observeLanguageChanges() {
        LocalizationManager.shared.$selectedLanguageCode
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] languageCode in
                guard let self else { return }
                self.messagingService.subscribeToDailyChallenges()
                if let userId = self.currentUser?.id {
                    Task {
                        try? await self.firestoreService.updateLanguageCode(
                            userId: userId,
                            languageCode: languageCode
                        )
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - FCM Token Observation

    private func observeFCMToken() {
        NotificationCenter.default.publisher(for: .fcmTokenReceived)
            .compactMap { $0.userInfo?["token"] as? String }
            .sink { [weak self] token in
                guard let self, let userId = self.currentUser?.id else { return }
                Task {
                    try? await self.firestoreService.updateFCMToken(userId: userId, token: token)
                    self.messagingService.subscribeToDailyChallenges()
                }
            }
            .store(in: &cancellables)
    }

    private func persistFCMTokenAndLanguage(userId: String) async {
        if let token = try? await Messaging.messaging().token() {
            try? await firestoreService.updateFCMToken(userId: userId, token: token)
            messagingService.subscribeToDailyChallenges()
        }

        let langCode = LocalizationManager.shared.selectedLanguageCode
        try? await firestoreService.updateLanguageCode(userId: userId, languageCode: langCode)
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
                    // Tear down listeners that hold a uid before clearing
                    // currentUser. Without this, listeners briefly query
                    // with a deleted/signed-out uid and Firestore floods the
                    // logs with `Missing or insufficient permissions`.
                    BlockedUsersStore.shared.stop()
                    PrivacyZonesStore.shared.stop()

                    self.currentUser = nil
                    self.shouldShowWelcome = false
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
                // Firestore is the source of truth for user profile data
                let syncedUser = try await firestoreService.syncUserSeasonState(user)
                let migratedUser = (try? await firestoreService.migrateUserSocialFieldsIfNeeded(syncedUser)) ?? syncedUser
                currentUser = migratedUser
                requiresProfileCompletion = Self.isDefaultDisplayName(migratedUser.displayName)
            } else {
                // First-time sign in — create user document
                let displayName = firebaseUser.displayName ?? ""
                let needsCompletion = displayName.isEmpty || Self.isDefaultDisplayName(displayName)
                let seasonId = SeasonService().generateCurrentSeason().id
                var newUser = User(
                    id: firebaseUser.uid,
                    displayName: displayName.isEmpty ? "runner.defaultName".localized : displayName,
                    email: firebaseUser.email ?? "",
                    color: Self.consumePendingUserColor() ?? Self.randomUserColor(),
                    currentSeasonId: seasonId
                )
                newUser.runnerProfile = Self.consumePendingRunnerProfile()
                try await firestoreService.createUser(newUser)
                currentUser = newUser
                requiresProfileCompletion = needsCompletion
                shouldShowWelcome = true
            }

            Task {
                do {
                    try await badgeService.syncAndEvaluateBadges(userId: firebaseUser.uid)
                } catch {
                    AppLogger.game.error("Badge sync failed: \(error.localizedDescription)")
                }
            }

            Task { await persistFCMTokenAndLanguage(userId: firebaseUser.uid) }
            Task { await refreshWeeklyWidget(userId: firebaseUser.uid) }

            // Start observing the user's blocked / blockedBy sets so feed,
            // search and profile views can filter reactively.
            BlockedUsersStore.shared.start(for: firebaseUser.uid)

            // Privacy zones live cache — consumed synchronously by PostService
            // when masking route previews.
            PrivacyZonesStore.shared.start(for: firebaseUser.uid)
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

    func resetOnboardingForTesting() {
        // Sign out so the user has to go through the auth step again.
        // Otherwise the .auth case in onboardingFlow calls completeOnboarding()
        // on appear and the still-authenticated user falls straight into MainTabView.
        if isAuthenticated {
            signOut()
        }

        isOnboardingComplete = false
        shouldShowWelcome = false
        requiresProfileCompletion = false

        UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.isOnboardingComplete)
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.hasRequestedLocationPermission)
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.hasRequestedNotificationPermission)
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.pendingRunnerProfile)
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.pendingUserColor)
    }

    func dismissWelcome() {
        shouldShowWelcome = false
    }

    // MARK: - Sign Out

    func signOut() {
        if let userId = currentUser?.id {
            Task { try? await firestoreService.clearFCMToken(userId: userId) }
        }
        // BlockedUsersStore.shared.stop() runs via observeAuthState() once
        // isAuthenticated flips to false — keeping it in one place avoids
        // drift between this and the account-deletion path.
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
        LocalizationManager.localizedStringInAllLanguages(forKey: "runner.defaultName").contains(name)
    }

    private static func randomUserColor() -> String {
        AppConstants.UserColors.all.randomElement() ?? "#4ECDC4"
    }

    private static func consumePendingRunnerProfile() -> RunnerProfile? {
        let key = AppConstants.UserDefaultsKeys.pendingRunnerProfile
        defer { UserDefaults.standard.removeObject(forKey: key) }
        guard let data = UserDefaults.standard.data(forKey: key),
              let profile = try? JSONDecoder().decode(RunnerProfile.self, from: data) else {
            return nil
        }
        return profile
    }

    private static func consumePendingUserColor() -> String? {
        let key = AppConstants.UserDefaultsKeys.pendingUserColor
        defer { UserDefaults.standard.removeObject(forKey: key) }
        guard let hex = UserDefaults.standard.string(forKey: key),
              AppConstants.UserColors.all.contains(hex) else {
            return nil
        }
        return hex
    }

    private func refreshWeeklyWidget(userId: String) async {
        do {
            let runs = try await firestoreService.getRunSessions(userId: userId, limit: 50)
            WidgetDataService.shared.buildAndSaveSummary(from: runs, currentUser: currentUser)
        } catch {
            AppLogger.firebase.warning("Failed to refresh widget on auth: \(error.localizedDescription)")
        }
    }
}
