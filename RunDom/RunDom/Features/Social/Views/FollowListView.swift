import SwiftUI

struct FollowListView: View {
    let userId: String
    let mode: FollowListMode

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: FollowListViewModel

    init(userId: String, mode: FollowListMode) {
        self.userId = userId
        self.mode = mode
        _viewModel = StateObject(wrappedValue: FollowListViewModel(userId: userId, mode: mode))
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                ProgressView()
                    .padding(.top, 60)
            } else if viewModel.entries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.entries) { entry in
                        NavigationLink {
                            UserProfileView(userId: entry.userId)
                                .environmentObject(appState)
                        } label: {
                            row(entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var navigationTitle: String {
        switch mode {
        case .followers: return "social.followers".localized
        case .following: return "social.following".localized
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, AppConstants.UI.screenPadding)
    }

    private var emptyMessage: String {
        switch mode {
        case .followers: return "social.followlist.empty.followers".localized
        case .following: return "social.followlist.empty.following".localized
        }
    }

    private func row(_ entry: FollowRelationship) -> some View {
        HStack(spacing: 12) {
            AvatarView(
                photoURL: entry.photoURL,
                userColor: entry.color ?? "#4ECDC4",
                size: 48
            )

            Text(entry.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}
