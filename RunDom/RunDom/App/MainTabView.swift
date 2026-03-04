import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter

    var body: some View {
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
                LeaderboardPlaceholderView()
            }
            .tabItem {
                Label("tab.leaderboard".localized, systemImage: "trophy.fill")
            }
            .tag(AppRouter.Tab.leaderboard)

            // Run Tab (center)
            NavigationStack {
                RunPlaceholderView()
            }
            .tabItem {
                Label("tab.run".localized, systemImage: "figure.run")
            }
            .tag(AppRouter.Tab.run)

            // Stats Tab
            NavigationStack {
                StatsPlaceholderView()
            }
            .tabItem {
                Label("tab.stats".localized, systemImage: "chart.bar.fill")
            }
            .tag(AppRouter.Tab.stats)

            // Profile Tab
            NavigationStack {
                ProfilePlaceholderView()
            }
            .tabItem {
                Label("tab.profile".localized, systemImage: "person.fill")
            }
            .tag(AppRouter.Tab.profile)
        }
        .sheet(item: $router.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
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
        case .badgeDetail:
            Text("profile.badges".localized)
        case .editProfile:
            Text("profile.editProfile".localized)
        case .settings:
            Text("settings.title".localized)
        }
    }
}

// MARK: - Placeholder Views

/// Placeholder views will be replaced in their respective feature steps.

private struct LeaderboardPlaceholderView: View {
    var body: some View {
        Text("tab.leaderboard".localized)
            .font(.largeTitle.bold())
            .navigationTitle("tab.leaderboard".localized)
    }
}

private struct RunPlaceholderView: View {
    var body: some View {
        Text("tab.run".localized)
            .font(.largeTitle.bold())
            .navigationTitle("tab.run".localized)
    }
}

private struct StatsPlaceholderView: View {
    var body: some View {
        Text("tab.stats".localized)
            .font(.largeTitle.bold())
            .navigationTitle("tab.stats".localized)
    }
}

private struct ProfilePlaceholderView: View {
    var body: some View {
        Text("tab.profile".localized)
            .font(.largeTitle.bold())
            .navigationTitle("tab.profile".localized)
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
