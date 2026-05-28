import Foundation

// Local-only registry of content the user has reported / dismissed.
// Reports go to Firestore; hiding is a per-device UX so the reporter
// stops seeing the offending item immediately, without waiting for
// moderator action.
@MainActor
final class HiddenContentStore: ObservableObject {
    static let shared = HiddenContentStore()

    @Published private(set) var hiddenPostIds: Set<String> = []
    @Published private(set) var hiddenCommentIds: Set<String> = []

    private let defaults: UserDefaults
    private let postsKey = "hiddenPostIds"
    private let commentsKey = "hiddenCommentIds"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hiddenPostIds = Set(defaults.stringArray(forKey: postsKey) ?? [])
        self.hiddenCommentIds = Set(defaults.stringArray(forKey: commentsKey) ?? [])
    }

    // MARK: - Posts

    func hidePost(_ postId: String) {
        guard !hiddenPostIds.contains(postId) else { return }
        hiddenPostIds.insert(postId)
        persist(hiddenPostIds, key: postsKey)
    }

    func isPostHidden(_ postId: String) -> Bool {
        hiddenPostIds.contains(postId)
    }

    func unhidePost(_ postId: String) {
        guard hiddenPostIds.contains(postId) else { return }
        hiddenPostIds.remove(postId)
        persist(hiddenPostIds, key: postsKey)
    }

    // MARK: - Comments

    func hideComment(_ commentId: String) {
        guard !hiddenCommentIds.contains(commentId) else { return }
        hiddenCommentIds.insert(commentId)
        persist(hiddenCommentIds, key: commentsKey)
    }

    func isCommentHidden(_ commentId: String) -> Bool {
        hiddenCommentIds.contains(commentId)
    }

    // MARK: - Helpers

    private func persist(_ set: Set<String>, key: String) {
        defaults.set(Array(set), forKey: key)
    }
}
