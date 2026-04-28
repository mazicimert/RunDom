import Foundation

enum AppConstants {

    // MARK: - Firebase

    enum Firebase {
        static let realtimeDBURL = "https://rundom-e7aad-default-rtdb.europe-west1.firebasedatabase.app"
    }

    // MARK: - Game Parameters (defaults — overridden by Remote Config)

    enum Game {
        static let basePointMultiplier: Double = 100
        static let minSpeedKmh: Double = 4.0
        static let maxSpeedKmh: Double = 18.0
        static let speedDivisor: Double = 10.0
        static let maxSpeedMultiplier: Double = 1.8
        static let maxDurationMultiplier: Double = 2.0
        static let durationDivisor: Double = 100.0
        static let maxDurationMinutes: Double = 120.0
        static let zoneMultiplierStep: Double = 0.1
        static let maxZoneMultiplier: Double = 2.0
        static let boostModeMultiplier: Double = 2.0
        static let boostMinSpeedKmh: Double = 7.0
        static let maxTrailPerRun: Double = 5_000
        static let maxTrailPerDay: Double = 15_000
        static let defenseDecayHours: Int = 48
        static let dropzoneRewardMultiplier: Double = 2.0
        static let dropzoneRewardDays: Int = 3
        static let dropzoneMaxClaimants: Int = 3
        static let dropzoneHintHours: Int = 24
    }

    // MARK: - Streak Tiers

    enum Streak {
        static let tier1Days = 3
        static let tier1Multiplier: Double = 1.2
        static let tier2Days = 7
        static let tier2Multiplier: Double = 1.5
        static let tier3Days = 14
        static let tier3Multiplier: Double = 2.0
        static let noStreakMultiplier: Double = 1.0
    }

    // MARK: - Anti-Farm Thresholds

    enum AntiFarm {
        static let highUniqueRatio: Double = 0.7
        static let highMultiplier: Double = 1.0
        static let mediumUniqueRatio: Double = 0.4
        static let mediumMultiplier: Double = 0.7
        static let lowMultiplier: Double = 0.4
    }

    // MARK: - Location

    enum Location {
        static let gpsGapThresholdSeconds: TimeInterval = 60
        static let h3Resolution: Int = 9
        static let rivalOverlayRing: Int = 2
    }

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let isOnboardingComplete = "isOnboardingComplete"
        static let hasRequestedLocationPermission = "hasRequestedLocationPermission"
        static let hasRequestedNotificationPermission = "hasRequestedNotificationPermission"
        static let lastKnownLatitude = "lastKnownLatitude"
        static let lastKnownLongitude = "lastKnownLongitude"
        static let appLanguageCode = "appLanguageCode"
        static let unitPreference = "unitPreference"
        static let lastDailyChallengePromptDateKey = "lastDailyChallengePromptDateKey"
        static let mapStyle = "mapStyle"
        static let voiceFeedbackEnabled = "voiceFeedbackEnabled"
        static let aiAnalysisEnabled = "aiAnalysisEnabled"
        static let aiDisclosureAccepted = "aiDisclosureAccepted"
    }

    // MARK: - Animation Durations

    enum Animation {
        static let standard: Double = 0.3
        static let quick: Double = 0.15
        static let splash: Double = 2.0
    }

    // MARK: - User Colors

    enum UserColors {
        static let all = [
            "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
            "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F",
            "#BB8FCE", "#85C1E9", "#F0B27A", "#82E0AA"
        ]
    }

    // MARK: - UI

    enum UI {
        static let cornerRadius: CGFloat = 16
        static let smallCornerRadius: CGFloat = 8
        static let cardPadding: CGFloat = 16
        static let screenPadding: CGFloat = 20
    }
}
