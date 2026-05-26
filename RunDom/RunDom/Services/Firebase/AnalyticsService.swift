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

    static func logOnboardingHookContinued() {
        Analytics.logEvent("onboarding_hook_continued", parameters: nil)
    }

    static func logOnboardingQuizCompleted(
        weeklyGoal: Int?,
        motivation: String?,
        experience: String?,
        mode: String?
    ) {
        var params: [String: Any] = [:]
        if let weeklyGoal { params["weekly_goal"] = weeklyGoal }
        if let motivation { params["motivation"] = motivation }
        if let experience { params["experience"] = experience }
        if let mode { params["preferred_mode"] = mode }
        Analytics.logEvent("onboarding_quiz_completed", parameters: params)
    }

    static func logOnboardingColorConfirmed(hex: String) {
        Analytics.logEvent("onboarding_color_confirmed", parameters: [
            "color_hex": hex
        ])
    }

    static func logOnboardingLocationPrimeShown() {
        Analytics.logEvent("onboarding_location_prime_shown", parameters: nil)
    }

    static func logOnboardingLocationAllowTapped() {
        Analytics.logEvent("onboarding_location_allow_tapped", parameters: nil)
    }

    static func logOnboardingLocationSkipped() {
        Analytics.logEvent("onboarding_location_skipped", parameters: nil)
    }

    static func logOnboardingFirstMissionShown() {
        Analytics.logEvent("onboarding_first_mission_shown", parameters: nil)
    }

    static func logOnboardingFirstMissionAction(action: String) {
        Analytics.logEvent("onboarding_first_mission_action", parameters: [
            "action": action
        ])
    }

    static func logPostRunNotificationPromptShown() {
        Analytics.logEvent("post_run_notification_prompt_shown", parameters: nil)
    }

    static func logPostRunNotificationPromptAllowTapped() {
        Analytics.logEvent("post_run_notification_prompt_allow_tapped", parameters: nil)
    }

    static func logPostRunNotificationPromptSkipped() {
        Analytics.logEvent("post_run_notification_prompt_skipped", parameters: nil)
    }

    static func logPostRunNotificationPromptResult(granted: Bool) {
        Analytics.logEvent("post_run_notification_prompt_result", parameters: [
            "granted": granted
        ])
    }

    static func logSettingsNotificationToggleTapped(currentStatus: String) {
        Analytics.logEvent("settings_notification_toggle_tapped", parameters: [
            "current_status": currentStatus
        ])
    }

    static func logSettingsNotificationPermissionResult(granted: Bool) {
        Analytics.logEvent("settings_notification_permission_result", parameters: [
            "granted": granted
        ])
    }

    static func logSettingsLocationToggleTapped(currentStatus: String) {
        Analytics.logEvent("settings_location_toggle_tapped", parameters: [
            "current_status": currentStatus
        ])
    }

    static func logMapLocationBannerShown(status: String) {
        Analytics.logEvent("map_location_banner_shown", parameters: [
            "status": status
        ])
    }

    static func logMapLocationBannerTapped(status: String) {
        Analytics.logEvent("map_location_banner_tapped", parameters: [
            "status": status
        ])
    }

    static func logPreRunBackgroundUpgradePromptShown() {
        Analytics.logEvent("prerun_background_upgrade_shown", parameters: nil)
    }

    static func logPreRunBackgroundUpgradeOpenSettings() {
        Analytics.logEvent("prerun_background_upgrade_open_settings", parameters: nil)
    }

    static func logPreRunBackgroundUpgradeStartAnyway() {
        Analytics.logEvent("prerun_background_upgrade_start_anyway", parameters: nil)
    }

    static func logPreRunBackgroundUpgradeDismissed() {
        Analytics.logEvent("prerun_background_upgrade_dismissed", parameters: nil)
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

    // MARK: - AI Analysis Events

    static func logAIRunAnalysisRequested(mode: RunMode) {
        Analytics.logEvent("ai_run_analysis_requested", parameters: [
            "mode": mode.rawValue
        ])
    }

    static func logAIRunAnalysisLoaded(source: AIAnalysisSource) {
        Analytics.logEvent("ai_run_analysis_loaded", parameters: [
            "source": source.rawValue
        ])
    }

    static func logAIRunAnalysisFailed(reason: String) {
        Analytics.logEvent("ai_run_analysis_failed", parameters: [
            "reason": reason
        ])
    }

    static func logAIWeeklyAnalysisRequested() {
        Analytics.logEvent("ai_weekly_analysis_requested", parameters: nil)
    }

    static func logAIWeeklyAnalysisLoaded(source: AIAnalysisSource) {
        Analytics.logEvent("ai_weekly_analysis_loaded", parameters: [
            "source": source.rawValue
        ])
    }

    static func logAIWeeklyAnalysisFailed(reason: String) {
        Analytics.logEvent("ai_weekly_analysis_failed", parameters: [
            "reason": reason
        ])
    }

    static func logAIDisclosureShown() {
        Analytics.logEvent("ai_disclosure_shown", parameters: nil)
    }

    static func logAIDisclosureAccepted() {
        Analytics.logEvent("ai_disclosure_accepted", parameters: nil)
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
