import Foundation
import FirebaseFirestore

final class CommentService {

    private let db = Firestore.firestore()

    private func commentsCollection(postId: String) -> CollectionReference {
        db.collection("posts").document(postId).collection("comments")
    }

    @discardableResult
    func addComment(postId: String, text: String, author: User) async throws -> Comment {
        let id = UUID().uuidString
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let comment = Comment(
            id: id,
            authorId: author.id,
            authorDisplayName: author.displayName,
            authorPhotoURL: author.photoURL,
            text: trimmed,
            createdAt: Date()
        )

        try commentsCollection(postId: postId).document(id).setData(from: comment)
        AppLogger.firebase.info("Comment added on post: \(postId)")
        return comment
    }

    func deleteComment(postId: String, commentId: String) async throws {
        try await commentsCollection(postId: postId).document(commentId).delete()
        AppLogger.firebase.info("Comment deleted on post: \(postId)")
    }

    func getComments(postId: String, limit: Int = 50) async throws -> [Comment] {
        let snapshot = try await commentsCollection(postId: postId)
            .order(by: "createdAt", descending: false)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Comment.self) }
    }
}
