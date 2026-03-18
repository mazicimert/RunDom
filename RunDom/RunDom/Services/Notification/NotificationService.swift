import Foundation
import UserNotifications

/// Manages local and push notification scheduling, permission handling,
/// and notification routing for game events.
final class NotificationService {

    // MARK: - Notification Type

    enum NotificationType: String {
        case territoryCaptured = "territory_captured"
        case dropzoneActive = "dropzone_active"
        case defenseDropping = "defense_dropping"
        case streakWarning = "streak_warning"
        case dailyChallenge = "daily_challenge"

        var categoryIdentifier: String { rawValue }
    }

    // MARK: - Singleton

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    /// Requests notification authorization. Returns true if granted.
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.hasRequestedNotificationPermission)
            AppLogger.notification.info("Notification permission \(granted ? "granted" : "denied")")
            return granted
        } catch {
            AppLogger.notification.error("Notification permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Returns the current notification authorization status.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Local Notification Scheduling

    /// Schedules a local notification for a territory capture event.
    func sendTerritoryCaptured(territoryIndex: String, capturerName: String?) async {
        let content = UNMutableNotificationContent()
        content.title = "notification.territoryCaptured.title".localized
        content.body = "notification.territoryCaptured".localized
        content.sound = .default
        content.userInfo = [
            "type": NotificationType.territoryCaptured.rawValue,
            "h3Index": territoryIndex
        ]
        content.categoryIdentifier = NotificationType.territoryCaptured.categoryIdentifier

        await schedule(content: content, identifier: "territory_\(territoryIndex)_\(Date().timeIntervalSince1970)")
    }

    /// Schedules a local notification for an active dropzone nearby.
    func sendDropzoneActive(dropzoneId: String, neighborhood: String?) async {
        let content = UNMutableNotificationContent()
        content.title = "notification.dropzoneActive.title".localized
        if let neighborhood {
            content.body = String(format: "notification.dropzoneActive.location".localized, neighborhood)
        } else {
            content.body = "notification.dropzoneActive".localized
        }
        content.sound = .default
        content.userInfo = [
            "type": NotificationType.dropzoneActive.rawValue,
            "dropzoneId": dropzoneId
        ]
        content.categoryIdentifier = NotificationType.dropzoneActive.categoryIdentifier

        await schedule(content: content, identifier: "dropzone_\(dropzoneId)")
    }

    /// Schedules a local notification warning about defense level decay.
    func sendDefenseDropping(territoryIndex: String, neighborhood: String?) async {
        let content = UNMutableNotificationContent()
        content.title = "notification.defenseDropping.title".localized
        if let neighborhood {
            content.body = String(format: "notification.defenseDropping.location".localized, neighborhood)
        } else {
            content.body = "notification.defenseDropping".localized
        }
        content.sound = .default
        content.userInfo = [
            "type": NotificationType.defenseDropping.rawValue,
            "h3Index": territoryIndex
        ]
        content.categoryIdentifier = NotificationType.defenseDropping.categoryIdentifier

        await schedule(content: content, identifier: "defense_\(territoryIndex)")
    }

    /// Schedules a streak warning notification at a given hour (default 20:00 local time).
    func scheduleStreakWarning(streakDays: Int, atHour hour: Int = 20) async {
        // Remove any existing streak warning first
        center.removePendingNotificationRequests(withIdentifiers: ["streak_warning"])

        let content = UNMutableNotificationContent()
        content.title = "notification.streakWarning.title".localized
        content.body = String(format: "notification.streakWarning.body".localized, streakDays)
        content.sound = .default
        content.userInfo = [
            "type": NotificationType.streakWarning.rawValue,
            "streakDays": streakDays
        ]
        content.categoryIdentifier = NotificationType.streakWarning.categoryIdentifier

        // Schedule for today at the specified hour
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "streak_warning",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            AppLogger.notification.info("Streak warning scheduled for \(hour):00")
        } catch {
            AppLogger.notification.error("Failed to schedule streak warning: \(error.localizedDescription)")
        }
    }

    /// Cancels the pending streak warning notification.
    func cancelStreakWarning() {
        center.removePendingNotificationRequests(withIdentifiers: ["streak_warning"])
        AppLogger.notification.info("Streak warning cancelled")
    }

    // MARK: - FCM Payload Handling

    /// Processes a remote notification payload and returns the notification type.
    func handleRemotePayload(_ userInfo: [AnyHashable: Any]) -> NotificationType? {
        guard let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString) else {
            AppLogger.notification.info("Unknown notification payload: \(userInfo)")
            return nil
        }
        AppLogger.notification.info("Handled remote notification: \(type.rawValue)")
        return type
    }

    /// Returns the deep-link destination for a notification type and its userInfo.
    func destination(for userInfo: [AnyHashable: Any]) -> NotificationDestination? {
        guard let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString) else {
            return nil
        }

        switch type {
        case .territoryCaptured:
            if let h3Index = userInfo["h3Index"] as? String {
                return .territory(h3Index: h3Index)
            }
            return .map
        case .dropzoneActive:
            if let dropzoneId = userInfo["dropzoneId"] as? String {
                return .dropzone(id: dropzoneId)
            }
            return .map
        case .defenseDropping:
            if let h3Index = userInfo["h3Index"] as? String {
                return .territory(h3Index: h3Index)
            }
            return .map
        case .streakWarning:
            return .run
        case .dailyChallenge:
            return .dailyChallenge
        }
    }

    // MARK: - Badge Management

    /// Updates the app badge count.
    func setBadgeCount(_ count: Int) async {
        do {
            try await center.setBadgeCount(count)
        } catch {
            AppLogger.notification.error("Failed to set badge count: \(error.localizedDescription)")
        }
    }

    /// Clears the app badge.
    func clearBadge() async {
        await setBadgeCount(0)
    }

    // MARK: - Cleanup

    /// Removes all delivered notifications.
    func removeAllDelivered() {
        center.removeAllDeliveredNotifications()
    }

    /// Removes all pending notification requests.
    func removeAllPending() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Private

    private func schedule(content: UNNotificationContent, identifier: String) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            AppLogger.notification.info("Scheduled notification: \(identifier)")
        } catch {
            AppLogger.notification.error("Failed to schedule notification \(identifier): \(error.localizedDescription)")
        }
    }
}

// MARK: - Notification Destination

enum NotificationDestination {
    case map
    case territory(h3Index: String)
    case dropzone(id: String)
    case run
    case profile
    case dailyChallenge
}
