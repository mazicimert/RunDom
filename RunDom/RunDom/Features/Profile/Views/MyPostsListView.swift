import SwiftUI

/// Full, paginated list of the current user's posts, pushed from the profile's
/// "See All" action.
struct MyPostsListView: View {
    let userId: String

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: MyPostsViewModel

    init(userId: String) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: MyPostsViewModel(userId: userId))
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView()
                    .padding(.top, 60)
            } else if viewModel.posts.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.posts) { post in
                        NavigationLink {
                            PostDetailView(postId: post.id)
                                .environmentObject(appState)
                        } label: {
                            ProfilePostRowView(post: post)
                        }
                        .buttonStyle(.plain)
                        .task { await viewModel.loadMoreIfNeeded(currentItem: post) }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("social.profile.posts.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.text.square")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("social.profile.posts.empty".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, AppConstants.UI.screenPadding)
    }
}
