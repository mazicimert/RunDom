import Foundation
import FirebaseFirestore

final class LikeService {

    private let db = Firestore.firestore()

    private func likesCollection(postId: String) -> CollectionReference {
        db.collection("posts").document(postId).collection("likes")
    }

    func like(postId: String, userId: String) async throws {
        try await likesCollection(postId: postId)
            .document(userId)
            .setData([
                "userId": userId,
                "createdAt": FieldValue.serverTimestamp()
            ])
        AppLogger.firebase.info("Liked post: \(postId)")
    }

    func unlike(postId: String, userId: String) async throws {
        try await likesCollection(postId: postId)
            .document(userId)
            .delete()
        AppLogger.firebase.info("Unliked post: \(postId)")
    }

    func isLiked(postId: String, userId: String) async throws -> Bool {
        let snapshot = try await likesCollection(postId: postId)
            .document(userId)
            .getDocument()
        return snapshot.exists
    }
}
