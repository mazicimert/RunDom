import Foundation
import FirebaseMessaging

final class MessagingService {
    // MARK: - Topics

    enum Topic: String {
        case allUsers = "all_users"
        case seasonReset = "season_reset"
        case dropzoneAlerts = "dropzone_alerts"
        case dailyChallengesEn = "daily_challenges_en"
        case dailyChallengesTr = "daily_challenges_tr"
        case dailyChallengesPt = "daily_challenges_pt"
        case dailyChallengesEs = "daily_challenges_es"
        case dailyChallengesDe = "daily_challenges_de"

        static let dailyChallengeTopics: [Topic] = [
            .dailyChallengesEn,
            .dailyChallengesTr,
            .dailyChallengesPt,
            .dailyChallengesEs,
            .dailyChallengesDe
        ]

        static func dailyChallengeTopic(for language: AppLanguage) -> Topic {
            switch language {
            case .english: return .dailyChallengesEn
            case .turkish: return .dailyChallengesTr
            case .portuguese: return .dailyChallengesPt
            case .spanish: return .dailyChallengesEs
            case .german: return .dailyChallengesDe
            }
        }
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
        subscribeToDailyChallenges()
    }

    func subscribeToDailyChallenges() {
        let selectedCode = LocalizationManager.shared.selectedLanguageCode
        let language = AppLanguage(rawValue: selectedCode) ?? .english
        let activeTopic = Topic.dailyChallengeTopic(for: language)

        subscribe(to: activeTopic)
        for topic in Topic.dailyChallengeTopics where topic != activeTopic {
            unsubscribe(from: topic)
        }
    }
}
