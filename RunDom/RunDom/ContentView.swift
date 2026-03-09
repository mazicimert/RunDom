import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter

    @StateObject private var onboardingVM = OnboardingViewModel()

    var body: some View {
        Group {
            if appState.isLoading {
                SplashView(onFinish: {})
            } else if !appState.isOnboardingComplete {
                onboardingFlow
            } else if !appState.isAuthenticated {
                AuthView(
                    viewModel: AuthViewModel(authService: appState.authService, appState: appState),
                    onComplete: {}
                )
            } else if appState.requiresProfileCompletion {
                CompleteProfileView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: AppConstants.Animation.standard), value: appState.isLoading)
        .animation(.easeInOut(duration: AppConstants.Animation.standard), value: appState.isAuthenticated)
        .animation(.easeInOut(duration: AppConstants.Animation.standard), value: appState.isOnboardingComplete)
        .animation(.easeInOut(duration: AppConstants.Animation.standard), value: appState.requiresProfileCompletion)
        .onAppear {
            onboardingVM.locationManager = appState.locationManager
        }
    }

    // MARK: - Onboarding Flow

    @ViewBuilder
    private var onboardingFlow: some View {
        switch onboardingVM.currentStep {
        case .splash:
            SplashView {
                onboardingVM.finishSplash()
            }
            .transition(.opacity)

        case .pages:
            OnboardingContainerView(viewModel: onboardingVM)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

        case .locationPermission:
            PermissionRequestView(
                type: .location,
                onAllow: { onboardingVM.requestLocationPermission() },
                onSkip: { onboardingVM.skipLocationPermission() }
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))

        case .notificationPermission:
            PermissionRequestView(
                type: .notification,
                onAllow: { onboardingVM.requestNotificationPermission() },
                onSkip: { onboardingVM.skipNotificationPermission() }
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))

        case .auth:
            AuthView(
                viewModel: AuthViewModel(authService: appState.authService, appState: appState),
                onComplete: {}
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .opacity
            ))
            .onAppear {
                appState.completeOnboarding()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
