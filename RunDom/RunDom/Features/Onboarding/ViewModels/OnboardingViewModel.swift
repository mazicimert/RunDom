import Combine
import CoreLocation
import SwiftUI
import UserNotifications

enum OnboardingMediaStyle: String, Codable {
    case screenshotCard
    case iconAccent
}

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - State

    enum Step: Int, CaseIterable {
        case splash
        case pages
        case locationPermission
        case notificationPermission
        case auth
    }

    @Published var currentStep: Step = .splash
    @Published var currentPage: Int = 0

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

    func finishSplash() {
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
            AnalyticsService.logOnboardingCompleted()
            advanceToPermissions()
        }
    }

    func skipPages() {
        AnalyticsService.logOnboardingSkipped(pageIndex: currentPage + 1)
        advanceToPermissions()
    }

    func trackPageViewed(_ pageIndex: Int) {
        guard pageIndex >= 0 && pageIndex < totalPages else { return }
        guard viewedPageIndexes.insert(pageIndex).inserted else { return }
        AnalyticsService.logOnboardingViewed(pageIndex: pageIndex + 1)
    }

    func supportingText(for pageIndex: Int) -> String {
        "onboarding.slide\(pageIndex + 1).support".localized
    }

    // MARK: - Permissions

    func requestLocationPermission() {
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
        advanceStep()
    }

    func requestNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
            UserDefaults.standard.set(
                true, forKey: AppConstants.UserDefaultsKeys.hasRequestedNotificationPermission)
            advanceStep()
        }
    }

    func skipNotificationPermission() {
        advanceStep()
    }

    // MARK: - Navigation Helpers

    private func advanceToPermissions() {
        let hasRequestedLocation = UserDefaults.standard.bool(
            forKey: AppConstants.UserDefaultsKeys.hasRequestedLocationPermission
        )

        withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
            if !hasRequestedLocation {
                currentStep = .locationPermission
            } else {
                currentStep = .notificationPermission
            }
        }
    }

    private func advanceStep() {
        withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
            switch currentStep {
            case .splash:
                currentStep = .pages
            case .pages:
                currentStep = .locationPermission
            case .locationPermission:
                currentStep = .notificationPermission
            case .notificationPermission:
                currentStep = .auth
            case .auth:
                break
            }
        }
    }
}
