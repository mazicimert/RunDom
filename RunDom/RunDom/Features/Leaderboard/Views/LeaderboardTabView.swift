import SwiftUI

struct LeaderboardTabView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: LeaderboardViewModel

    init(locationManager: LocationManager) {
        _viewModel = StateObject(wrappedValue: LeaderboardViewModel(locationManager: locationManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Scope Picker
            Picker("", selection: $viewModel.scope) {
                Text("leaderboard.global".localized)
                    .tag(LeaderboardScope.global)
                Text("leaderboard.neighborhood".localized)
                    .tag(LeaderboardScope.neighborhood)
            }
            .pickerStyle(.segmented)
            .screenPadding()
            .padding(.vertical, 8)

            // Content
            if viewModel.isLoading {
                Spacer()
                LoadingView()
                Spacer()
            } else if viewModel.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "trophy",
                    title: "leaderboard.empty".localized,
                    subtitle: "leaderboard.empty.subtitle".localized
                )
                Spacer()
            } else {
                ScrollView {
                    LeaderboardListView(
                        entries: viewModel.entries,
                        currentUserId: appState.currentUser?.id
                    )
                    .padding(.bottom)
                }
            }
        }
        .navigationTitle("tab.leaderboard".localized)
        .task {
            await viewModel.loadLeaderboard(currentUser: appState.currentUser)
        }
        .refreshable {
            await viewModel.loadLeaderboard(currentUser: appState.currentUser)
        }
        .onChange(of: viewModel.scope) { _, _ in
            Task {
                await viewModel.loadLeaderboard(currentUser: appState.currentUser)
            }
        }
    }
}

#Preview {
    NavigationStack {
        LeaderboardTabView(locationManager: LocationManager())
            .environmentObject(AppState())
    }
}
