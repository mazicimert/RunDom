import Foundation

@MainActor
final class UserProfileViewModel: ObservableObject {

    @Published var user: User?
    @Published var posts: [Post] = []
    @Published var isFollowing = false
    @Published var isLoading = false
    @Published var isProcessingFollow = false
    @Published var isProcessingBlock = false
    @Published var errorMessage: String?

    let targetUserId: String

    private let firestoreService: FirestoreService
    private let postService: PostService
    private let followService: FollowService
    private let blockService: BlockService

    init(
        targetUserId: String,
        firestoreService: FirestoreService = FirestoreService(),
        postService: PostService = PostService(),
        followService: FollowService = FollowService(),
        blockService: BlockService = BlockService()
    ) {
        self.targetUserId = targetUserId
        self.firestoreService = firestoreService
        self.postService = postService
        self.followService = followService
        self.blockService = blockService
    }

    func load(currentUserId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            user = try await firestoreService.getUser(id: targetUserId)
        } catch {
            AppLogger.firebase.error("Failed to load target user: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }

        if currentUserId != targetUserId {
            do {
                isFollowing = try await followService.isFollowing(
                    currentUserId: currentUserId,
                    targetUserId: targetUserId
                )
            } catch {
                AppLogger.firebase.warning("isFollowing check failed: \(error.localizedDescription)")
            }
        }

        // Tolerate failure: post visibility opens up in a later phase. Empty
        // list is the correct state until then.
        do {
            let result = try await postService.getPosts(byUser: targetUserId, limit: 10)
            posts = result.posts
        } catch {
            posts = []
        }

        isLoading = false
    }

    func toggleFollow(currentUserId: String) async {
        guard let user else { return }
        guard currentUserId != targetUserId else { return }

        isProcessingFollow = true
        defer { isProcessingFollow = false }

        do {
            if isFollowing {
                try await followService.unfollow(
                    currentUserId: currentUserId,
                    targetUserId: targetUserId
                )
                isFollowing = false
                applyFollowerDelta(-1)
            } else {
                try await followService.follow(currentUserId: currentUserId, target: user)
                isFollowing = true
                applyFollowerDelta(1)
            }
        } catch {
            AppLogger.firebase.error("Follow toggle failed: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }
    }

    func block(currentUserId: String) async {
        guard let user, currentUserId != targetUserId else { return }
        isProcessingBlock = true
        defer { isProcessingBlock = false }

        do {
            try await blockService.block(currentUserId: currentUserId, target: user)
            // Optimistic: clear follow state — Cloud Function tears down the
            // actual edges + counters. UI reflects the new reality immediately.
            if isFollowing { isFollowing = false }
        } catch {
            AppLogger.firebase.error("Block failed: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }
    }

    func unblock(currentUserId: String) async {
        guard currentUserId != targetUserId else { return }
        isProcessingBlock = true
        defer { isProcessingBlock = false }

        do {
            try await blockService.unblock(
                currentUserId: currentUserId,
                targetUserId: targetUserId
            )
        } catch {
            AppLogger.firebase.error("Unblock failed: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }
    }

    private func applyFollowerDelta(_ delta: Int) {
        guard var current = user else { return }
        let next = max(0, (current.followersCount ?? 0) + delta)
        current.followersCount = next
        user = current
    }
}
