import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header: Avatar + Name
                profileHeader

                // Stats Cards
                statsSection

                // Streak Info
                if let user = viewModel.user ?? appState.currentUser, user.streakDays > 0 {
                    streakSection(user: user)
                }

                // Badges
                badgesSection

                // Action Buttons
                actionButtons
            }
            .padding(.vertical)
        }
        .navigationTitle("tab.profile".localized)
        .refreshable {
            if let userId = appState.currentUser?.id {
                await viewModel.loadProfile(userId: userId)
            }
        }
        .task {
            if let userId = appState.currentUser?.id {
                await viewModel.loadProfile(userId: userId)
            }
        }
        .onChange(of: appState.currentUser) { _, newUser in
            if let newUser {
                viewModel.user = newUser
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.user == nil {
                LoadingView()
            }
        }
    }

    // MARK: - Badges Accessor (for sheet routing)

    var loadedBadges: [Badge] { viewModel.badges }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            let user = viewModel.user ?? appState.currentUser

            AvatarView(
                photoURL: user?.photoURL,
                userColor: user?.color ?? "#4ECDC4",
                size: 100
            )

            Text(user?.displayName ?? "runner.defaultName".localized)
                .font(.title2.bold())

            if let neighborhood = user?.neighborhood {
                Label(neighborhood, systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .screenPadding()
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        let user = viewModel.user ?? appState.currentUser

        return HStack(spacing: 12) {
            StatCardView(
                icon: "flame.fill",
                value: (user?.totalTrail ?? 0).formattedTrail,
                label: "profile.totalTrail".localized,
                iconColor: .orange
            )
            StatCardView(
                icon: "figure.run",
                value: "\(user?.totalRuns ?? 0)",
                label: "profile.totalRuns".localized,
                iconColor: .blue
            )
            StatCardView(
                icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                value: (user?.totalDistance ?? 0).formattedDistanceFromMeters,
                label: "profile.totalDistance".localized,
                iconColor: .green
            )
        }
        .screenPadding()
    }

    // MARK: - Streak Section

    private func streakSection(user: User) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "profile.streakDays".localized, user.streakDays))
                    .font(.headline)

                Text(String(format: "profile.streakMultiplier".localized, String(format: "x%.1f", user.streakMultiplier)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .cardStyle()
        .screenPadding()
    }

    // MARK: - Badges Section

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("profile.badges".localized)
                    .font(.headline)

                Spacer()

                if !viewModel.badges.isEmpty {
                    Text("\(viewModel.unlockedBadges.count)/\(viewModel.badges.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            BadgeGridView(badges: viewModel.badges) { badge in
                router.presentedSheet = .badgeDetail(badge: badge)
            }
        }
        .screenPadding()
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                router.presentedSheet = .editProfile
            } label: {
                Label("profile.editProfile".localized, systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())

            Button {
                router.presentedSheet = .settings
            } label: {
                Label("profile.settings".localized, systemImage: "gearshape")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .screenPadding()
    }

}

#Preview {
    NavigationStack {
        ProfileTabView()
            .environmentObject(AppState())
            .environmentObject(AppRouter())
    }
}
