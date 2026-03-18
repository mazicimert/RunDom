import UIKit
import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // FCM delegate
        Messaging.messaging().delegate = self

        // Register for remote notifications
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()

        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
           let destination = NotificationService.shared.destination(for: userInfo) {
            NotificationService.shared.setPendingDestination(destination)
        }

        AppLogger.firebase.info("Firebase configured successfully")
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLogger.firebase.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        AppLogger.firebase.info("FCM token received")
        NotificationCenter.default.post(
            name: .fcmTokenReceived,
            object: nil,
            userInfo: ["token": token]
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        AppLogger.notification.info("Notification tapped: \(userInfo)")

        guard let destination = NotificationService.shared.destination(for: userInfo) else { return }
        NotificationService.shared.setPendingDestination(destination)
        NotificationCenter.default.post(
            name: .notificationTapped,
            object: nil,
            userInfo: ["destination": destination]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let fcmTokenReceived = Notification.Name("fcmTokenReceived")
    static let notificationTapped = Notification.Name("notificationTapped")
}
