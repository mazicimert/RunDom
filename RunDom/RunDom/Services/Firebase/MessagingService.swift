import Foundation
import FirebaseMessaging

final class MessagingService {
    // MARK: - Topics

    enum Topic: String {
        case allUsers = "all_users"
        case seasonReset = "season_reset"
        case dropzoneAlerts = "dropzone_alerts"
    }

    // MARK: - FCM Token

    func getFCMToken() async throws -> String {
        try await Messaging.messaging().token()
    }

    // MARK: - Topic Subscriptions

    func subscribe(to topic: Topic) {
        Messaging.messaging().subscribe(toTopic: topic.rawValue) { error in
            if let error {
                AppLogger.firebase.error("Failed to subscribe to \(topic.rawValue): \(error.localizedDescription)")
            } else {
                AppLogger.firebase.info("Subscribed to topic: \(topic.rawValue)")
            }
        }
    }

    func unsubscribe(from topic: Topic) {
        Messaging.messaging().unsubscribe(fromTopic: topic.rawValue) { error in
            if let error {
                AppLogger.firebase.error("Failed to unsubscribe from \(topic.rawValue): \(error.localizedDescription)")
            } else {
                AppLogger.firebase.info("Unsubscribed from topic: \(topic.rawValue)")
            }
        }
    }

    // MARK: - Setup

    func subscribeToDefaults() {
        subscribe(to: .allUsers)
        subscribe(to: .seasonReset)
        subscribe(to: .dropzoneAlerts)
    }
}
