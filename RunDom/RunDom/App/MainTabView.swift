import SwiftUI
import UserNotifications

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase

    @State private var activeRunSession: RunSession?
    @State private var completedRunSession: RunSession?
    @State private var showDailyChallengePrompt = false

    private let dailyChallengeService = DailyChallengeService()

    var body: some View {
        ZStack {
            TabView(selection: $router.selectedTab) {
                // Map Tab
                NavigationStack {
                    MapTabView(locationManager: appState.locationManager)
                }
                .tabItem {
                    Label("tab.map".localized, systemImage: "map.fill")
                }
                .tag(AppRouter.Tab.map)

                // Leaderboard Tab
                NavigationStack {
                    LeaderboardTabView(locationManager: appState.locationManager)
                }
                .tabItem {
                    Label("tab.leaderboard".localized, systemImage: "trophy.fill")
                }
                .tag(AppRouter.Tab.leaderboard)

                // Run Tab (center)
                NavigationStack {
                    PreRunView(locationManager: appState.locationManager) { mode in
                        startRun(mode: mode)
                    }
                }
                .tabItem {
                    Label("tab.run".localized, systemImage: "figure.run")
                }
                .tag(AppRouter.Tab.run)

                // Stats Tab
                NavigationStack {
                    StatsTabView()
                }
                .tabItem {
                    Label("tab.stats".localized, systemImage: "chart.bar.fill")
                }
                .tag(AppRouter.Tab.stats)

                // Profile Tab
                NavigationStack {
                    ProfileTabView()
                }
                .tabItem {
                    Label("tab.profile".localized, systemImage: "person.fill")
                }
                .tag(AppRouter.Tab.profile)
            }

            // Full-screen active run overlay
            if router.isRunActive, let userId = appState.currentUser?.id,
               let userColor = appState.currentUser?.color {
                ActiveRunView(
                    viewModel: ActiveRunViewModel(
                        mode: activeRunSession?.mode ?? .normal,
                        userId: userId,
                        userColor: userColor,
                        locationManager: appState.locationManager
                    ),
                    onFinish: { session in
                        completedRunSession = session
                        router.isRunActive = false
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
        .onChange(of: router.selectedTab) {
            Haptics.selection()
        }
        .sheet(item: $router.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .fullScreenCover(item: $completedRunSession) { session in
            PostRunSummaryView(session: session) {
                completedRunSession = nil
            }
            .environmentObject(appState)
        }
        .sheet(isPresented: $showDailyChallengePrompt) {
            DailyChallengePromptSheet {
                showDailyChallengePrompt = false
            } onOpenChallenges: {
                router.selectedTab = .run
                showDailyChallengePrompt = false
            }
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .task(id: appState.currentUser?.id) {
            await presentDailyChallengePromptIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationTapped)) { notification in
            guard let destination = notification.userInfo?["destination"] as? NotificationDestination else { return }
            router.handleNotificationDestination(destination)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                UNUserNotificationCenter.current().setBadgeCount(0)
            }
        }
    }

    // MARK: - Run Actions

    private func startRun(mode: RunMode) {
        activeRunSession = RunSession(
            id: UUID().uuidString,
            userId: appState.currentUser?.id ?? "",
            mode: mode,
            startDate: Date()
        )
        router.isRunActive = true
    }

    private func presentDailyChallengePromptIfNeeded() async {
        guard appState.currentUser != nil else { return }
        guard dailyChallengeService.shouldShowDailyPrompt() else { return }
        guard await dailyChallengeService.hasAvailableChallenges() else { return }
        dailyChallengeService.markDailyPromptShown()
        showDailyChallengePrompt = true
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: AppRouter.Sheet) -> some View {
        switch sheet {
        case .runSession:
            Text("run.start".localized)
        case .postRunSummary:
            Text("run.summary".localized)
        case .territoryDetail:
            Text("map.myTerritory".localized)
        case .dropzoneDetail:
            Text("dropzone.active".localized)
        case .badgeDetail(let badge):
            BadgeDetailView(badge: badge)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .editProfile:
            EditProfileView()
                .environmentObject(appState)
        case .settings:
            SettingsView(authService: appState.authService)
                .environmentObject(appState)
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}

private struct DailyChallengePromptSheet: View {
    let onDismiss: () -> Void
    let onOpenChallenges: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("challenge.prompt.title".localized)
                .font(.title3.bold())

            Text("challenge.prompt.body".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("common.cancel".localized) {
                    onDismiss()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("challenge.prompt.action".localized) {
                    onOpenChallenges()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
}
