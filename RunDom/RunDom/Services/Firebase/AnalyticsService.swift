import Foundation
import FirebaseAnalytics

enum AnalyticsService {

    // MARK: - Onboarding Events

    static func logOnboardingViewed(pageIndex: Int) {
        Analytics.logEvent("onboarding_viewed", parameters: [
            "page_index": pageIndex
        ])
    }

    static func logOnboardingNext(pageIndex: Int) {
        Analytics.logEvent("onboarding_next", parameters: [
            "page_index": pageIndex
        ])
    }

    static func logOnboardingSkipped(pageIndex: Int) {
        Analytics.logEvent("onboarding_skipped", parameters: [
            "page_index": pageIndex
        ])
    }

    static func logOnboardingCompleted() {
        Analytics.logEvent("onboarding_completed", parameters: nil)
    }

    // MARK: - Run Events

    static func logRunStarted(mode: RunMode) {
        Analytics.logEvent("run_started", parameters: [
            "mode": mode.rawValue
        ])
    }

    static func logRunCompleted(distance: Double, duration: TimeInterval, trail: Double, territories: Int, mode: RunMode) {
        Analytics.logEvent("run_completed", parameters: [
            "distance_km": distance,
            "duration_seconds": duration,
            "trail_earned": trail,
            "territories_captured": territories,
            "mode": mode.rawValue
        ])
    }

    // MARK: - Territory Events

    static func logTerritoryCaptured(h3Index: String) {
        Analytics.logEvent("territory_captured", parameters: [
            "h3_index": h3Index
        ])
    }

    // MARK: - Dropzone Events

    static func logDropzoneClaimed(dropzoneId: String) {
        Analytics.logEvent("dropzone_claimed", parameters: [
            "dropzone_id": dropzoneId
        ])
    }

    // MARK: - Badge Events

    static func logBadgeUnlocked(badgeId: String, category: String) {
        Analytics.logEvent("badge_unlocked", parameters: [
            "badge_id": badgeId,
            "category": category
        ])
    }

    // MARK: - Auth Events

    static func logSignIn(method: String) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [
            AnalyticsParameterMethod: method
        ])
    }

    static func logSignUp(method: String) {
        Analytics.logEvent(AnalyticsEventSignUp, parameters: [
            AnalyticsParameterMethod: method
        ])
    }

    // MARK: - Screen Views

    static func logScreenView(name: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name
        ])
    }

    // MARK: - User Properties

    static func setUserId(_ userId: String) {
        Analytics.setUserID(userId)
    }

    static func setUserProperty(name: String, value: String) {
        Analytics.setUserProperty(value, forName: name)
    }
}
