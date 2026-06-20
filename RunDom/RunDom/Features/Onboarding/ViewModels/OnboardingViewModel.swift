import Combine
import CoreLocation
import SwiftUI
import UIKit

/// Visual content of a "How it works" onboarding slide.
enum OnboardingMedia {
    /// A seamlessly-looping, muted video (Screen 1 — the run/paint wow moment).
    case video(resource: String, fileExtension: String)
    /// Two phone screenshots side by side, with an optional notification banner
    /// floating over the top (Screen 2: map + attack notification, Screen 3:
    /// feed + leaderboard).
    case dualScreenshot(leading: String, trailing: String, topOverlay: String?)
}

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - State

    enum Step: Int, CaseIterable {
        case splash
        case hook
        case pages
        case quiz
        case colorReveal
        case locationPermission
        case auth
    }

    @Published var currentStep: Step = .splash
    @Published var currentPage: Int = 0
    @Published var currentQuizIndex: Int = 0
    @Published var pendingProfile: RunnerProfile = RunnerProfile()
    @Published var pendingColor: String = ""
    @Published private(set) var locationAuthStatus: CLAuthorizationStatus = .notDetermined

    let totalQuizQuestions = 4

    // MARK: - Dependencies

    var locationManager: LocationManager? {
        didSet { locationManagerDidChange() }
    }
    private var cancellables = Set<AnyCancellable>()
    private var locationStatusCancellable: AnyCancellable?
    private var viewedPageIndexes = Set<Int>()

    private func locationManagerDidChange() {
        locationStatusCancellable?.cancel()
        guard let locationManager else {
            locationAuthStatus = .notDetermined
            return
        }
        locationAuthStatus = locationManager.authorizationStatus
        locationStatusCancellable = locationManager.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.locationAuthStatus = status
            }
    }

    // MARK: - Page Data

    struct PageData {
        let titleKey: String
        let subtitleKey: String
        let media: OnboardingMedia
        let accentColor: Color
        let primaryCTAKey: String?
    }

    var totalPages: Int { pages.count }

    var pages: [PageData] {
        [
            // Screen 1 — Run, paint the map (looping run video).
            PageData(
                titleKey: "onboarding.slide1.title",
                subtitleKey: "onboarding.slide1.subtitle",
                media: .video(resource: "onboarding_run_loop", fileExtension: "mp4"),
                accentColor: .blue,
                primaryCTAKey: nil
            ),
            // Screen 2 — Claim & defend (map overview + detail, attack banner).
            PageData(
                titleKey: "onboarding.slide2.title",
                subtitleKey: "onboarding.slide2.subtitle",
                media: .dualScreenshot(
                    leading: "onboarding_map_overview",
                    trailing: "onboarding_map_detail",
                    topOverlay: "onboarding_attack_notification"
                ),
                accentColor: .green,
                primaryCTAKey: nil
            ),
            // Screen 3 — Compete & share (feed + leaderboard).
            PageData(
                titleKey: "onboarding.slide3.title",
                subtitleKey: "onboarding.slide3.subtitle",
                media: .dualScreenshot(
                    leading: "onboarding_feed",
                    trailing: "onboarding_leaderboard",
                    topOverlay: nil
                ),
                accentColor: .orange,
                primaryCTAKey: "onboarding.getStarted"
            ),
        ]
    }

    // MARK: - Splash

    func resetToStart() {
        cancellables.removeAll()
        viewedPageIndexes.removeAll()
        currentPage = 0
        currentQuizIndex = 0
        pendingProfile = RunnerProfile()
        pendingColor = ""
        currentStep = .splash
    }

    func finishSplash() {
        withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
            currentStep = .hook
        }
    }

    // MARK: - Hook

    func continueFromHook() {
        AnalyticsService.logOnboardingHookContinued()
        withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
            currentStep = .pages
        }
    }

    // MARK: - Pages

    func nextPage() {
        AnalyticsService.logOnboardingNext(pageIndex: currentPage + 1)

        if currentPage < totalPages - 1 {
            withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
                currentPage += 1
            }
        } else {
            advanceToQuiz()
        }
    }

    func skipPages() {
        AnalyticsService.logOnboardingSkipped(pageIndex: currentPage + 1)
        advanceToQuiz()
    }

    func trackPageViewed(_ pageIndex: Int) {
        guard pageIndex >= 0 && pageIndex < totalPages else { return }
        guard viewedPageIndexes.insert(pageIndex).inserted else { return }
        AnalyticsService.logOnboardingViewed(pageIndex: pageIndex + 1)
    }

    func supportingText(for pageIndex: Int) -> String {
        "onboarding.slide\(pageIndex + 1).support".localized
    }

    // MARK: - Quiz

    var isLastQuizQuestion: Bool {
        currentQuizIndex >= totalQuizQuestions - 1
    }

    var canAdvanceQuiz: Bool {
        switch currentQuizIndex {
        case 0: return pendingProfile.weeklyGoal != nil
        case 1: return pendingProfile.motivation != nil
        case 2: return pendingProfile.experience != nil
        case 3: return pendingProfile.preferredMode != nil
        default: return false
        }
    }

    func selectWeeklyGoal(_ goal: WeeklyRunGoal) {
        Haptics.selection()
        pendingProfile.weeklyGoal = goal
    }

    func selectMotivation(_ motivation: RunnerMotivation) {
        Haptics.selection()
        pendingProfile.motivation = motivation
    }

    func selectExperience(_ experience: RunnerExperience) {
        Haptics.selection()
        pendingProfile.experience = experience
    }

    func selectMode(_ mode: RunMode) {
        Haptics.selection()
        pendingProfile.preferredMode = mode
    }

    func advanceQuiz() {
        Haptics.impact(.light)
        if isLastQuizQuestion {
            persistPendingProfile()
            AnalyticsService.logOnboardingQuizCompleted(
                weeklyGoal: pendingProfile.weeklyGoal?.rawValue,
                motivation: pendingProfile.motivation?.rawValue,
                experience: pendingProfile.experience?.rawValue,
                mode: pendingProfile.preferredMode?.rawValue
            )
            advanceToColorReveal()
        } else {
            withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
                currentQuizIndex += 1
            }
        }
    }

    func previousQuiz() {
        if currentQuizIndex > 0 {
            withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
                currentQuizIndex -= 1
            }
        } else {
            withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
                currentStep = .pages
            }
        }
    }

    private func persistPendingProfile() {
        guard let data = try? JSONEncoder().encode(pendingProfile) else { return }
        UserDefaults.standard.set(data, forKey: AppConstants.UserDefaultsKeys.pendingRunnerProfile)
    }

    // MARK: - Color Reveal

    var availableColors: [String] {
        AppConstants.UserColors.all
    }

    func ensurePendingColor() {
        guard pendingColor.isEmpty else { return }
        pendingColor = availableColors.randomElement() ?? "#4ECDC4"
    }

    func selectColor(_ hex: String) {
        guard pendingColor != hex else { return }
        Haptics.selection()
        pendingColor = hex
    }

    func confirmColorReveal() {
        guard !pendingColor.isEmpty else { return }
        Haptics.impact(.medium)
        UserDefaults.standard.set(pendingColor, forKey: AppConstants.UserDefaultsKeys.pendingUserColor)
        AnalyticsService.logOnboardingColorConfirmed(hex: pendingColor)
        advanceToPermissions()
    }

    func backFromColorReveal() {
        withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
            currentQuizIndex = totalQuizQuestions - 1
            currentStep = .quiz
        }
    }

    private func advanceToColorReveal() {
        ensurePendingColor()
        withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
            currentStep = .colorReveal
        }
    }

    // MARK: - Permissions

    func requestLocationPermission() {
        AnalyticsService.logOnboardingLocationAllowTapped()

        let status = locationAuthStatus

        switch status {
        case .notDetermined:
            // Normal flow: trigger system prompt and wait for the user's choice
            UserDefaults.standard.set(
                true, forKey: AppConstants.UserDefaultsKeys.hasRequestedLocationPermission)
            guard let locationManager else {
                advanceStep()
                return
            }
            locationManager.requestAlwaysAuthorization()
            locationManager.$authorizationStatus
                .dropFirst()  // skip current value
                .first()  // only first change
                .receive(on: DispatchQueue.main)
                .sink { [weak self] (_: CLAuthorizationStatus) in
                    self?.advanceStep()
                }
                .store(in: &cancellables)

        case .denied, .restricted:
            // iOS won't show the system prompt again. Deep-link to Settings.
            // The view's scenePhase observer will auto-advance if the user
            // grants permission and returns.
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }

        case .authorizedAlways, .authorizedWhenInUse:
            // Already granted — defensive: just advance.
            advanceStep()

        @unknown default:
            advanceStep()
        }
    }

    /// Called by LocationPrimingView when the scene returns to foreground.
    /// If the user upgraded permission via iOS Settings, advance to the
    /// next step automatically.
    func reevaluateLocationStatusOnReturn() {
        guard currentStep == .locationPermission else { return }
        let status = locationAuthStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            advanceStep()
        }
    }

    func skipLocationPermission() {
        AnalyticsService.logOnboardingLocationSkipped()
        advanceStep()
    }

    // MARK: - Navigation Helpers

    private func advanceToQuiz() {
        AnalyticsService.logOnboardingCompleted()
        withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
            currentQuizIndex = 0
            currentStep = .quiz
        }
    }

    private func advanceToPermissions() {
        // Skip the LocationPriming step entirely if iOS already has a granted
        // answer — we can't re-trigger the system prompt anyway. The recovery
        // surfaces (Map banner, Settings, PreRun) handle whenInUse upgrades.
        let status = locationAuthStatus
        let alreadyAuthorized = status == .authorizedAlways || status == .authorizedWhenInUse

        withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
            currentStep = alreadyAuthorized ? .auth : .locationPermission
        }
    }

    private func advanceStep() {
        withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
            switch currentStep {
            case .splash:
                currentStep = .hook
            case .hook:
                currentStep = .pages
            case .pages:
                currentStep = .quiz
            case .quiz:
                currentStep = .colorReveal
            case .colorReveal:
                currentStep = .locationPermission
            case .locationPermission:
                currentStep = .auth
            case .auth:
                break
            }
        }
    }
}
