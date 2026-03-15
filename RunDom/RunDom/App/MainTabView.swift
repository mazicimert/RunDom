import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter

    @State private var activeRunSession: RunSession?
    @State private var completedRunSession: RunSession?

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
        case .badgeDetail(let badgeId):
            BadgeDetailView(badge: Badge(
                id: badgeId,
                nameKey: badgeId,
                descriptionKey: badgeId,
                iconName: "rosette",
                category: .performance,
                isSecret: false
            ))
        case .editProfile:
            EditProfileView()
                .environmentObject(appState)
        case .settings:
            SettingsView()
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
