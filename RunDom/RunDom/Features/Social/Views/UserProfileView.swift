import SwiftUI

struct UserProfileView: View {
    let userId: String

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: UserProfileViewModel
    @ObservedObject private var blockedStore = BlockedUsersStore.shared

    @State private var showBlockConfirm = false
    @State private var showUnblockConfirm = false
    @State private var showReportSheet = false

    init(userId: String) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(targetUserId: userId))
    }

    private var isOwnProfile: Bool {
        appState.currentUser?.id == userId
    }

    private var isBlockingTarget: Bool {
        blockedStore.isBlocking(userId)
    }

    private var isBlockedByTarget: Bool {
        blockedStore.isBlockedBy(userId)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                followCounterRow

                if !isOwnProfile && !isBlockingTarget && !isBlockedByTarget {
                    followButton
                        .padding(.horizontal, AppConstants.UI.screenPadding)
                }

                statsSection

                if isBlockingTarget {
                    blockedByMeOverlay
                } else if isBlockedByTarget {
                    blockedByOtherOverlay
                } else {
                    postsSection
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(viewModel.user?.displayName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isOwnProfile, viewModel.user != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    actionMenu
                }
            }
        }
        .task(id: userId) {
            guard let currentUserId = appState.currentUser?.id else { return }
            await viewModel.load(currentUserId: currentUserId)
        }
        .refreshable {
            guard let currentUserId = appState.currentUser?.id else { return }
            await viewModel.load(currentUserId: currentUserId)
        }
        .confirmationDialog(
            "social.block.confirm.title".localized(with: viewModel.user?.displayName ?? ""),
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("social.block.action".localized, role: .destructive) {
                guard let currentUserId = appState.currentUser?.id else { return }
                Task { await viewModel.block(currentUserId: currentUserId) }
            }
            Button("common.cancel".localized, role: .cancel) {}
        } message: {
            Text("social.block.confirm.message".localized)
        }
        .confirmationDialog(
            "social.unblock.confirm.title".localized(with: viewModel.user?.displayName ?? ""),
            isPresented: $showUnblockConfirm,
            titleVisibility: .visible
        ) {
            Button("social.unblock.action".localized) {
                guard let currentUserId = appState.currentUser?.id else { return }
                Task { await viewModel.unblock(currentUserId: currentUserId) }
            }
            Button("common.cancel".localized, role: .cancel) {}
        }
        .sheet(isPresented: $showReportSheet) {
            ReportReasonSheet(
                targetType: .user,
                targetId: userId,
                postId: nil
            ) {
                // Reporting a user implies hiding them; treat it as a block
                // so the rest of the UI filters them consistently.
                guard let currentUserId = appState.currentUser?.id,
                      viewModel.user != nil else { return }
                Task { await viewModel.block(currentUserId: currentUserId) }
            }
            .environmentObject(appState)
        }
    }

    // MARK: - Toolbar

    private var actionMenu: some View {
        Menu {
            if isBlockingTarget {
                Button {
                    showUnblockConfirm = true
                } label: {
                    Label("social.unblock.action".localized, systemImage: "person.crop.circle.badge.checkmark")
                }
            } else {
                Button(role: .destructive) {
                    showBlockConfirm = true
                } label: {
                    Label("social.block.action".localized, systemImage: "person.crop.circle.badge.xmark")
                }

                Button {
                    showReportSheet = true
                } label: {
                    Label("social.user.report".localized, systemImage: "flag")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
        }
        .disabled(viewModel.isProcessingBlock)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            if let user = viewModel.user {
                AvatarView(photoURL: user.photoURL, userColor: user.color, size: 100)
                Text(user.displayName)
                    .font(.title2.bold())
                if let neighborhood = user.neighborhood {
                    Label(neighborhood, systemImage: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 40)
            }
        }
        .frame(maxWidth: .infinity)
        .screenPadding()
    }

    private var followCounterRow: some View {
        HStack(spacing: 12) {
            NavigationLink {
                FollowListView(userId: userId, mode: .followers)
                    .environmentObject(appState)
            } label: {
                counterCard(
                    value: viewModel.user?.followersCount ?? 0,
                    label: "social.followers".localized
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                FollowListView(userId: userId, mode: .following)
                    .environmentObject(appState)
            } label: {
                counterCard(
                    value: viewModel.user?.followingCount ?? 0,
                    label: "social.following".localized
                )
            }
            .buttonStyle(.plain)
        }
        .screenPadding()
    }

    private func counterCard(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var followButton: some View {
        Button {
            guard let currentUserId = appState.currentUser?.id else { return }
            Task { await viewModel.toggleFollow(currentUserId: currentUserId) }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isProcessingFollow {
                    ProgressView()
                        .tint(viewModel.isFollowing ? .primary : .white)
                } else {
                    Image(systemName: viewModel.isFollowing ? "checkmark" : "plus")
                    Text(viewModel.isFollowing
                         ? "social.unfollow".localized
                         : "social.follow".localized)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(viewModel.isFollowing ? AnyButtonStyle(SecondaryButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle()))
        .disabled(viewModel.isProcessingFollow)
    }

    @ViewBuilder
    private var statsSection: some View {
        if let user = viewModel.user, !isBlockingTarget, !isBlockedByTarget {
            HStack(spacing: 12) {
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
            }
            .screenPadding()
        }
    }

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("social.userprofile.posts.title".localized)
                .font(.headline)

            if viewModel.posts.isEmpty {
                Text("social.userprofile.posts.empty".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.posts) { post in
                        postRow(post)
                    }
                }
            }
        }
        .screenPadding()
    }

    private func postRow(_ post: Post) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((Color(hex: post.authorColor) ?? Color.accentColor).opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: "figure.run")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hex: post.authorColor) ?? .accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(post.distance.formattedDistanceFromMeters)
                        .font(.subheadline.weight(.semibold))
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("trail.points".localized(with: post.trail.formattedTrail))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if let note = post.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Text(post.createdAt.relativeFormatted())
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    // MARK: - Block Overlays

    private var blockedByMeOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("social.block.overlay.byme".localized)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("social.block.overlay.byme.subtitle".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showUnblockConfirm = true
            } label: {
                Text("social.unblock.action".localized)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, 4)
            .disabled(viewModel.isProcessingBlock)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .screenPadding()
    }

    private var blockedByOtherOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("social.block.overlay.byother".localized)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .screenPadding()
    }
}

// Wrapping ButtonStyle so we can pick at the call site without type erasure
// gymnastics in the View body.
private struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { config in AnyView(style.makeBody(configuration: config)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}
