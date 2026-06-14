import FirebaseFirestore
import SwiftUI

@MainActor
final class MyPostsViewModel: ObservableObject {

    // MARK: - Published State

    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published private(set) var canLoadMore = true

    // MARK: - Services

    private let userId: String
    private let postService: PostService
    private let pageSize = 20
    private var lastDocument: DocumentSnapshot?

    // MARK: - Init

    init(userId: String, postService: PostService = PostService()) {
        self.userId = userId
        self.postService = postService
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        lastDocument = nil
        canLoadMore = true
        do {
            let result = try await postService.getPosts(byUser: userId, limit: pageSize)
            posts = result.posts
            lastDocument = result.lastDocument
            canLoadMore = result.posts.count == pageSize
        } catch {
            AppLogger.firebase.warning("Failed to load my posts: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func loadMoreIfNeeded(currentItem: Post) async {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        guard currentItem.id == posts.last?.id else { return }

        isLoadingMore = true
        do {
            let result = try await postService.getPosts(byUser: userId, limit: pageSize, after: lastDocument)
            posts.append(contentsOf: result.posts)
            lastDocument = result.lastDocument
            canLoadMore = result.posts.count == pageSize
        } catch {
            AppLogger.firebase.warning("Failed to load more posts: \(error.localizedDescription)")
            canLoadMore = false
        }
        isLoadingMore = false
    }
}
