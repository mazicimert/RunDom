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
                if let user = resolvedUser, user.streakDays > 0 {
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
        .task(id: appState.currentUser?.id) {
            if let userId = appState.currentUser?.id {
                await viewModel.loadProfile(userId: userId)
            }
        }
        .onChange(of: appState.currentUser) { _, newUser in
            if let newUser {
                viewModel.user = newUser
            } else {
                viewModel.user = nil
                viewModel.badges = []
            }
        }
    }

    // MARK: - Badges Accessor (for sheet routing)

    var loadedBadges: [Badge] { viewModel.badges }

    private var resolvedUser: User? {
        viewModel.user ?? appState.currentUser
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            if let user = resolvedUser {
                AvatarView(
                    photoURL: user.photoURL,
                    userColor: user.color,
                    size: 100
                )

                Text(user.displayName)
                    .font(.title2.bold())

                if let neighborhood = user.neighborhood {
                    Label(neighborhood, systemImage: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ProfileSkeletonAvatar()
                ProfileSkeletonBlock(width: 132, height: 22)
                ProfileSkeletonBlock(width: 96, height: 14)
            }
        }
        .screenPadding()
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 12) {
            if let user = resolvedUser {
                StatCardView(
                    icon: "flame.fill",
                    value: user.totalTrail.formattedTrail,
                    label: "profile.totalTrail".localized,
                    iconColor: .orange
                )
                StatCardView(
                    icon: "figure.run",
                    value: "\(user.totalRuns)",
                    label: "profile.totalRuns".localized,
                    iconColor: .blue
                )
                StatCardView(
                    icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                    value: user.totalDistance.formattedDistanceFromMeters,
                    label: "profile.totalDistance".localized,
                    iconColor: .green
                )
            } else {
                ProfileSkeletonStatCard()
                ProfileSkeletonStatCard()
                ProfileSkeletonStatCard()
            }
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

            if viewModel.isLoading && viewModel.badges.isEmpty {
                ProfileBadgesSkeleton()
            } else {
                BadgeGridView(badges: viewModel.badges) { badge in
                    router.presentedSheet = .badgeDetail(badge: badge)
                }
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

private struct ProfileSkeletonAvatar: View {
    var body: some View {
        Circle()
            .fill(Color.secondary.opacity(0.16))
            .frame(width: 100, height: 100)
            .shimmer()
    }
}

private struct ProfileSkeletonStatCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color.secondary.opacity(0.16))
                .frame(width: 20, height: 20)
                .shimmer()

            ProfileSkeletonBlock(width: 56, height: 22)
            ProfileSkeletonBlock(width: 44, height: 12)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

private struct ProfileBadgesSkeleton: View {
    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.secondary.opacity(0.16))
                        .frame(width: 56, height: 56)
                        .shimmer()

                    ProfileSkeletonBlock(width: 54, height: 12)
                    ProfileSkeletonBlock(width: 38, height: 4)
                }
                .frame(width: 80)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ProfileSkeletonBlock: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.secondary.opacity(0.16))
            .frame(width: width, height: height)
            .shimmer()
    }
}
