import SwiftUI
import UserNotifications

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published State

    @Published var notificationsEnabled = false
    @Published var showSignOutAlert = false
    @Published var showDeleteAccountAlert = false
    @Published var isDeleting = false
    @Published var errorMessage: String?

    // MARK: - Services

    private let authService: AuthService

    // MARK: - Init

    init(authService: AuthService? = nil) {
        self.authService = authService ?? AuthService()
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

    func deleteAccount() async {
        isDeleting = true
        do {
            try await authService.deleteAccount()
        } catch {
            AppLogger.auth.error("Failed to delete account: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }
        isDeleting = false
    }
}
