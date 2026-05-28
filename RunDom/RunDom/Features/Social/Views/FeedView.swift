import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = FeedViewModel()
    @ObservedObject private var hiddenStore = HiddenContentStore.shared
    @ObservedObject private var blockedStore = BlockedUsersStore.shared

    private var visiblePosts: [Post] {
        viewModel.posts.filter { post in
            !hiddenStore.isPostHidden(post.id)
            && !blockedStore.hasBlockRelationship(with: post.authorId)
        }
    }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.vertical, 12)
        }
        .background(Color.surfacePrimary.ignoresSafeArea())
        .refreshable {
            guard let userId = appState.currentUser?.id else { return }
            await viewModel.refresh(currentUserId: userId)
        }
        .task(id: appState.currentUser?.id) {
            guard let userId = appState.currentUser?.id else { return }
            await viewModel.loadInitial(currentUserId: userId)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage {
            ErrorBannerView(
                message: errorMessage,
                onDismiss: { viewModel.errorMessage = nil },
                onRetry: {
                    guard let userId = appState.currentUser?.id else { return }
                    Task { await viewModel.refresh(currentUserId: userId) }
                }
            )
        }

        if viewModel.isLoading && visiblePosts.isEmpty {
            ProgressView()
                .padding(.top, 80)
                .frame(maxWidth: .infinity)
        } else if visiblePosts.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 16) {
                ForEach(visiblePosts) { post in
                    PostCardView(post: post)
                        .environmentObject(appState)
                        .onAppear {
                            // Use the unfiltered tail so pagination still fires
                            // when the only hidden items are at the bottom.
                            if post.id == viewModel.posts.last?.id {
                                guard let userId = appState.currentUser?.id else { return }
                                Task { await viewModel.loadMore(currentUserId: userId) }
                            }
                        }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "newspaper")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("social.feed.empty.title".localized)
                .font(.headline)

            Text("social.feed.empty.subtitle".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                router.presentedSheet = .userSearch
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text("social.feed.empty.cta".localized)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 4)
        }
        .padding(.top, 60)
        .padding(.horizontal, 8)
    }
}
