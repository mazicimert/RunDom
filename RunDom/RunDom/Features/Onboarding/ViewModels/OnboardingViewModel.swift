import Combine
import CoreLocation
import SwiftUI
import UserNotifications

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

    let totalPages = 3

    // MARK: - Dependencies

    var locationManager: LocationManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Page Data

    struct PageData {
        let icon: String
        let title: String
        let subtitle: String
    }

    var pages: [PageData] {
        [
            PageData(
                icon: "map.fill",
                title: "onboarding.slide1.title".localized,
                subtitle: "onboarding.slide1.subtitle".localized
            ),
            PageData(
                icon: "flame.fill",
                title: "onboarding.slide2.title".localized,
                subtitle: "onboarding.slide2.subtitle".localized
            ),
            PageData(
                icon: "trophy.fill",
                title: "onboarding.slide3.title".localized,
                subtitle: "onboarding.slide3.subtitle".localized
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
        if currentPage < totalPages - 1 {
            withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
                currentPage += 1
            }
        } else {
            advanceToPermissions()
        }
    }

    func skipPages() {
        advanceToPermissions()
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
