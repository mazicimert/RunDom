import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let errorMessage = viewModel.errorMessage {
                    ErrorBannerView(
                        message: errorMessage,
                        onDismiss: {
                            withAnimation {
                                viewModel.errorMessage = nil
                            }
                        },
                        onRetry: retryLoadProfile
                    )
                }

                profileHeader

                statsSection

                latestRunSection

                if let user = resolvedUser, user.streakDays > 0 {
                    streakSection(user: user)
                } else if resolvedUser != nil {
                    streakMotivationSection
                }

                badgesSection
            }
            .padding(.vertical)
        }
        .navigationTitle("tab.profile".localized)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.presentedSheet = .settings
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("profile.settings".localized)
            }
        }
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
                if viewModel.user?.id != newUser.id {
                    viewModel.latestRun = nil
                }
                viewModel.user = newUser
            } else {
                viewModel.user = nil
                viewModel.badges = []
                viewModel.latestRun = nil
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
        ZStack(alignment: .topTrailing) {
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

                    levelPill(for: user)
                } else {
                    ProfileSkeletonAvatar()
                    ProfileSkeletonBlock(width: 132, height: 22)
                    ProfileSkeletonBlock(width: 96, height: 14)
                }
            }
            .frame(maxWidth: .infinity)

            if resolvedUser != nil {
                Button {
                    router.presentedSheet = .editProfile
                } label: {
                    Image(systemName: "pencil")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .background(Color.cardBackground, in: Circle())
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                .accessibilityLabel("profile.editProfile".localized)
            }
        }
        .screenPadding()
    }

    private func levelPill(for user: User) -> some View {
        let progress = PlayerLevel(totalTrail: user.totalTrail)
        let remainingPointsText = "trail.points".localized(with: progress.remaining.formattedTrail)

        return Button {
            Haptics.selection()
            router.presentedSheet = .levelBreakdown(totalTrail: user.totalTrail)
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))

                    Text("profile.level.title".localized(with: progress.level))
                        .font(.caption.weight(.semibold))

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text("profile.level.remaining".localized(with: remainingPointsText))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(Color.accentColor)

                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
                    .tint(Color.accentColor)
                    .frame(maxWidth: 220)
                    .accessibilityValue(Text("\(Int((progress.fraction * 100).rounded()))%"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("profile.level.sheet.accessibilityHint".localized)
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

    // MARK: - Latest Run Section

    @ViewBuilder
    private var latestRunSection: some View {
        if let latestRun = viewModel.latestRun {
            latestRunCard(latestRun)
        }
    }

    private func latestRunCard(_ run: RunSession) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.14))
                    .frame(width: 42, height: 42)

                Image(systemName: "figure.run.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("profile.latestRun.title".localized)
                        .font(.headline)

                    Spacer()

                    Text(run.startDate.relativeFormatted())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    latestRunMetric(
                        icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                        text: run.distance.formattedDistanceFromMeters,
                        color: .green
                    )

                    latestRunMetric(
                        icon: "flame.fill",
                        text: "trail.points".localized(with: run.trail.formattedTrail),
                        color: .orange
                    )
                }
            }
        }
        .cardStyle()
        .screenPadding()
    }

    private func latestRunMetric(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)

            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.12))
        )
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

    private var streakMotivationSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("profile.streakStart.title".localized)
                    .font(.headline)

                Text("profile.streakStart.subtitle".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

    private func retryLoadProfile() {
        guard let userId = appState.currentUser?.id else { return }
        Task {
            await viewModel.loadProfile(userId: userId)
        }
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

