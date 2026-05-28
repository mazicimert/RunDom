import Foundation

extension Notification.Name {
    /// Broadcast when a post's like/comment counts change from a child screen
    /// (PostDetailView). Feed-side view models listen and reconcile cards so
    /// the user doesn't have to pull-to-refresh after commenting/liking.
    /// userInfo: ["postId": String, "likeCount": Int, "commentCount": Int]
    static let socialPostCountsChanged = Notification.Name("socialPostCountsChanged")
}

@MainActor
final class PostDetailViewModel: ObservableObject {

    let postId: String

    @Published var post: Post?
    @Published var author: User?
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isPostingComment = false
    @Published var errorMessage: String?

    private let postService: PostService
    private let commentService: CommentService
    private let firestoreService: FirestoreService

    init(
        postId: String,
        postService: PostService = PostService(),
        commentService: CommentService = CommentService(),
        firestoreService: FirestoreService = FirestoreService()
    ) {
        self.postId = postId
        self.postService = postService
        self.commentService = commentService
        self.firestoreService = firestoreService
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            post = try await postService.getPost(id: postId)
        } catch {
            AppLogger.firebase.error("Failed to load post: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }

        // Fetch the canonical author so the hero shows the user's current
        // photoURL / displayName / color rather than the snapshot taken when
        // the post was created.
        if let authorId = post?.authorId {
            do {
                author = try await firestoreService.getUser(id: authorId)
            } catch {
                AppLogger.firebase.warning("Failed to load author: \(error.localizedDescription)")
            }
        }

        do {
            comments = try await commentService.getComments(postId: postId, limit: 50)
        } catch {
            AppLogger.firebase.warning("Failed to load comments: \(error.localizedDescription)")
            comments = []
        }

        isLoading = false
    }

    func addComment(text: String, author: User) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isPostingComment else { return }

        isPostingComment = true
        defer { isPostingComment = false }

        do {
            let comment = try await commentService.addComment(
                postId: postId,
                text: trimmed,
                author: author
            )
            comments.append(comment)
            if var current = post {
                current.commentCount += 1
                post = current
            }
            broadcastCountsChanged()
        } catch {
            AppLogger.firebase.error("Add comment failed: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }
    }

    func deleteComment(_ comment: Comment) async {
        do {
            try await commentService.deleteComment(postId: postId, commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
            if var current = post {
                current.commentCount = max(0, current.commentCount - 1)
                post = current
            }
            broadcastCountsChanged()
        } catch {
            AppLogger.firebase.error("Delete comment failed: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }
    }

    func canDelete(_ comment: Comment, currentUserId: String?) -> Bool {
        guard let currentUserId else { return false }
        if comment.authorId == currentUserId { return true }
        if post?.authorId == currentUserId { return true }
        return false
    }

    /// Called from the view when the user toggles the like state. Updates the
    /// local post counter and broadcasts so the feed card stays in sync.
    func applyLikeDelta(_ delta: Int) {
        guard var current = post else { return }
        current.likeCount = max(0, current.likeCount + delta)
        post = current
        broadcastCountsChanged()
    }

    private func broadcastCountsChanged() {
        guard let post else { return }
        NotificationCenter.default.post(
            name: .socialPostCountsChanged,
            object: nil,
            userInfo: [
                "postId": post.id,
                "likeCount": post.likeCount,
                "commentCount": post.commentCount
            ]
        )
    }
}
