import Combine
import CoreLocation
import SwiftUI

enum OnboardingMediaStyle: String, Codable {
    case screenshotCard
    case iconAccent
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

    let totalQuizQuestions = 4

    // MARK: - Dependencies

    var locationManager: LocationManager?
    private var cancellables = Set<AnyCancellable>()
    private var viewedPageIndexes = Set<Int>()

    // MARK: - Page Data

    struct PageData {
        let titleKey: String
        let subtitleKey: String
        let mediaAssetName: String
        let mediaStyle: OnboardingMediaStyle
        let accentColor: Color
        let primaryCTAKey: String?
    }

    var totalPages: Int { pages.count }

    var pages: [PageData] {
        [
            PageData(
                titleKey: "onboarding.slide1.title",
                subtitleKey: "onboarding.slide1.subtitle",
                mediaAssetName: "onboarding_map_mock",
                mediaStyle: .screenshotCard,
                accentColor: .blue,
                primaryCTAKey: nil
            ),
            PageData(
                titleKey: "onboarding.slide2.title",
                subtitleKey: "onboarding.slide2.subtitle",
                mediaAssetName: "onboarding_run_mock",
                mediaStyle: .screenshotCard,
                accentColor: .green,
                primaryCTAKey: nil
            ),
            PageData(
                titleKey: "onboarding.slide3.title",
                subtitleKey: "onboarding.slide3.subtitle",
                mediaAssetName: "onboarding_stats_mock",
                mediaStyle: .screenshotCard,
                accentColor: .orange,
                primaryCTAKey: nil
            ),
            PageData(
                titleKey: "onboarding.slide4.title",
                subtitleKey: "onboarding.slide4.subtitle",
                mediaAssetName: "onboarding_start_mock",
                mediaStyle: .screenshotCard,
                accentColor: .mint,
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
        locationManager?.requestAlwaysAuthorization()
        UserDefaults.standard.set(
            true, forKey: AppConstants.UserDefaultsKeys.hasRequestedLocationPermission)

        // Kullanıcının cevabını bekle — authorizationStatus değiştiğinde ilerle
        guard let locationManager = locationManager else {
            advanceStep()
            return
        }
        locationManager.$authorizationStatus
            .dropFirst()  // Mevcut değeri atla
            .first()  // Sadece ilk değişikliği al
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: CLAuthorizationStatus) in
                self?.advanceStep()
            }
            .store(in: &cancellables)
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
        let hasRequestedLocation = UserDefaults.standard.bool(
            forKey: AppConstants.UserDefaultsKeys.hasRequestedLocationPermission
        )

        withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
            if !hasRequestedLocation {
                currentStep = .locationPermission
            } else {
                currentStep = .auth
            }
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
