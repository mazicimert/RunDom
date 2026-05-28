import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class FeedViewModel: ObservableObject {

    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private let feedService: FeedService
    private var lastDocument: DocumentSnapshot?
    private var hasMore = true
    private var cancellables = Set<AnyCancellable>()

    init(feedService: FeedService = FeedService()) {
        self.feedService = feedService
        subscribeToCountsChanges()
    }

    func loadInitial(currentUserId: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        lastDocument = nil
        hasMore = true

        do {
            let result = try await feedService.getFeed(userId: currentUserId, limit: 20)
            posts = result.posts
            lastDocument = result.lastDocument
            hasMore = result.posts.count == 20
        } catch {
            AppLogger.firebase.error("Feed load failed: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
            posts = []
        }

        isLoading = false
    }

    func refresh(currentUserId: String) async {
        lastDocument = nil
        hasMore = true
        await loadInitial(currentUserId: currentUserId)
    }

    func loadMore(currentUserId: String) async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        guard let lastDocument else { return }

        isLoadingMore = true

        do {
            let result = try await feedService.getFeed(
                userId: currentUserId,
                limit: 20,
                after: lastDocument
            )
            posts.append(contentsOf: result.posts)
            self.lastDocument = result.lastDocument
            hasMore = result.posts.count == 20
        } catch {
            AppLogger.firebase.warning("Feed pagination failed: \(error.localizedDescription)")
        }

        isLoadingMore = false
    }

    private func subscribeToCountsChanges() {
        NotificationCenter.default.publisher(for: .socialPostCountsChanged)
            .compactMap { $0.userInfo }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userInfo in
                guard let self else { return }
                Task { @MainActor in
                    self.apply(countsUpdate: userInfo)
                }
            }
            .store(in: &cancellables)
    }

    private func apply(countsUpdate userInfo: [AnyHashable: Any]) {
        guard let postId = userInfo["postId"] as? String,
              let likeCount = userInfo["likeCount"] as? Int,
              let commentCount = userInfo["commentCount"] as? Int else { return }
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        posts[index].likeCount = likeCount
        posts[index].commentCount = commentCount
    }
}
