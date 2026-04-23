import SwiftUI
import UserNotifications
import FirebaseAuth

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published State

    @Published var notificationsEnabled = false
    @Published var showSignOutAlert = false
    @Published var showDeleteAccountAlert = false
    @Published var isDeleting = false
    @Published var errorMessage: String?
    @Published var isVoiceFeedbackEnabled: Bool {
        didSet {
            guard isVoiceFeedbackEnabled != oldValue else { return }
            UserDefaults.standard.set(
                isVoiceFeedbackEnabled,
                forKey: AppConstants.UserDefaultsKeys.voiceFeedbackEnabled
            )
        }
    }

    // MARK: - Services

    private let authService: AuthService
    private let firestoreService: FirestoreService
    private let realtimeDBService: RealtimeDBService
    private let offlineStorageService: OfflineStorageService

    // MARK: - Init

    init(
        authService: AuthService,
        firestoreService: FirestoreService = FirestoreService(),
        realtimeDBService: RealtimeDBService = RealtimeDBService(),
        offlineStorageService: OfflineStorageService = .shared
    ) {
        self.authService = authService
        self.firestoreService = firestoreService
        self.realtimeDBService = realtimeDBService
        self.offlineStorageService = offlineStorageService
        let storedVoice = UserDefaults.standard.object(
            forKey: AppConstants.UserDefaultsKeys.voiceFeedbackEnabled
        ) as? Bool
        self.isVoiceFeedbackEnabled = storedVoice ?? true
    }

    // MARK: - App Info

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Notifications

    func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
    }

    func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Account

    func deleteAccount() async -> Bool {
        guard let userId = authService.currentUser?.uid else {
            errorMessage = "error.generic".localized
            return false
        }

        isDeleting = true
        defer { isDeleting = false }

        do {
            if try await authService.requiresRecentSignInForAccountDeletion() {
                errorMessage = "settings.deleteAccountRecentLogin".localized
                return false
            }

            _ = try await realtimeDBService.deleteTerritoriesOwned(by: userId)
            try await firestoreService.deleteUserAccountData(userId: userId)
            try? offlineStorageService.clearAll()
            try await authService.deleteAccount()
            return true
        } catch {
            AppLogger.auth.error("Failed to delete account: \(error.localizedDescription)")
            if let authErrorCode = AuthErrorCode(rawValue: (error as NSError).code),
               authErrorCode == .requiresRecentLogin {
                errorMessage = "settings.deleteAccountRecentLogin".localized
            } else {
                errorMessage = "error.generic".localized
            }
            return false
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
