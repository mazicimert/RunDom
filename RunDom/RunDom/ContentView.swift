import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        Group {
            if appState.isLoading {
                loadingView
            } else if !appState.isOnboardingComplete {
                onboardingPlaceholder
            } else if !appState.isAuthenticated {
                authPlaceholder
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: AppConstants.Animation.standard), value: appState.isLoading)
        .animation(.easeInOut(duration: AppConstants.Animation.standard), value: appState.isAuthenticated)
        .animation(.easeInOut(duration: AppConstants.Animation.standard), value: appState.isOnboardingComplete)
    }

    // MARK: - Loading

    private var loadingView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            ProgressView()
                .scaleEffect(1.5)
        }
    }

    // MARK: - Placeholders (replaced in Step 6: Onboarding & Auth Flow)

    private var onboardingPlaceholder: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.run")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("RunDom")
                .font(.largeTitle.bold())

            Text("onboarding.slide1.subtitle".localized)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppConstants.UI.screenPadding)

            Button("onboarding.getStarted".localized) {
                appState.completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var authPlaceholder: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("auth.signInApple".localized)
                .font(.title2.bold())
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
