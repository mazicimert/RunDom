import Combine
import CoreLocation
import SwiftUI
import UserNotifications
import FirebaseAuth

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published State

    @Published var notificationsEnabled = false
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    @Published var showSignOutAlert = false
    @Published var showDeleteAccountAlert = false
    @Published var showDeleteReauthSheet = false
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
    @Published var isAIAnalysisEnabled: Bool {
        didSet {
            guard isAIAnalysisEnabled != oldValue else { return }
            UserDefaults.standard.set(
                isAIAnalysisEnabled,
                forKey: AppConstants.UserDefaultsKeys.aiAnalysisEnabled
            )
        }
    }

    // MARK: - Services

    private let authService: AuthService
    private let firestoreService: FirestoreService
    private let realtimeDBService: RealtimeDBService
    private let offlineStorageService: OfflineStorageService
    private weak var locationManager: LocationManager?
    private var cancellables = Set<AnyCancellable>()

    // Exposed for the re-auth sheet which needs the same AuthService instance
    // so the captured Apple authorizationCode survives across views.
    var authServicePublic: AuthService { authService }

    // MARK: - Init

    init(
        authService: AuthService,
        firestoreService: FirestoreService = FirestoreService(),
        realtimeDBService: RealtimeDBService = RealtimeDBService(),
        offlineStorageService: OfflineStorageService = .shared,
        locationManager: LocationManager? = nil
    ) {
        self.authService = authService
        self.firestoreService = firestoreService
        self.realtimeDBService = realtimeDBService
        self.offlineStorageService = offlineStorageService
        self.locationManager = locationManager
        let storedVoice = UserDefaults.standard.object(
            forKey: AppConstants.UserDefaultsKeys.voiceFeedbackEnabled
        ) as? Bool
        self.isVoiceFeedbackEnabled = storedVoice ?? true
        let storedAI = UserDefaults.standard.object(
            forKey: AppConstants.UserDefaultsKeys.aiAnalysisEnabled
        ) as? Bool
        self.isAIAnalysisEnabled = storedAI ?? true

        if let locationManager {
            self.locationAuthStatus = locationManager.authorizationStatus
            locationManager.$authorizationStatus
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    self?.locationAuthStatus = status
                }
                .store(in: &cancellables)
        }
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
        notificationStatus = settings.authorizationStatus
        notificationsEnabled = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    /// Toggle action handler.
    /// - notDetermined: requests system permission inline
    /// - authorized / denied / provisional: opens iOS Settings (the only way to change once decided)
    func handleNotificationToggleTap() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        AnalyticsService.logSettingsNotificationToggleTapped(
            currentStatus: Self.statusName(settings.authorizationStatus)
        )

        if settings.authorizationStatus == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            UserDefaults.standard.set(
                true,
                forKey: AppConstants.UserDefaultsKeys.hasRequestedNotificationPermission
            )
            AnalyticsService.logSettingsNotificationPermissionResult(granted: granted)
            await checkNotificationStatus()
        } else {
            openNotificationSettings()
        }
    }

    func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Location

    /// Toggle is "on" when the user has granted some level of location access.
    /// Background runs need .authorizedAlways, but for the toggle visual we
    /// treat .authorizedWhenInUse as on too (footer hint warns about background).
    var locationEnabled: Bool {
        locationAuthStatus == .authorizedAlways || locationAuthStatus == .authorizedWhenInUse
    }

    func handleLocationToggleTap() {
        AnalyticsService.logSettingsLocationToggleTapped(
            currentStatus: Self.locationStatusName(locationAuthStatus)
        )

        switch locationAuthStatus {
        case .notDetermined:
            locationManager?.requestAlwaysAuthorization()
        case .denied, .restricted, .authorizedWhenInUse, .authorizedAlways:
            openLocationSettings()
        @unknown default:
            openLocationSettings()
        }
    }

    private func openLocationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static func locationStatusName(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }

    private static func statusName(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Account

    /// Step 1 of deletion: user confirmed the destructive alert. We open the
    /// re-auth sheet so the user signs in with Apple again — this gives us a
    /// fresh authorizationCode for server-side Apple token revocation and
    /// satisfies Firebase's "requires recent login" guarantee.
    func startAccountDeletion() {
        showDeleteReauthSheet = true
    }

    /// Step 2 of deletion: called by the re-auth sheet after a successful
    /// Apple Sign In re-authentication. Triggers the Cloud Function which
    /// cascades through Firestore, Storage, Apple token revocation and the
    /// Firebase Auth record itself.
    func performDeletionAfterReauth() async -> Bool {
        isDeleting = true
        defer { isDeleting = false }

        do {
            // Clear local-only state ahead of the server call so the offline
            // cache doesn't outlive the account.
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
