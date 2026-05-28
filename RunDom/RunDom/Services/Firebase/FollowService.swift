import Foundation
import FirebaseFirestore

final class FollowService {

    private let db = Firestore.firestore()

    private var usersCollection: CollectionReference {
        db.collection("users")
    }

    private func followingCollection(of userId: String) -> CollectionReference {
        usersCollection.document(userId).collection("following")
    }

    private func followersCollection(of userId: String) -> CollectionReference {
        usersCollection.document(userId).collection("followers")
    }

    // MARK: - Follow / Unfollow

    func follow(currentUserId: String, target: User) async throws {
        guard currentUserId != target.id else { return }

        let relationship = FollowRelationship(
            userId: target.id,
            displayName: target.displayName,
            photoURL: target.photoURL,
            createdAt: Date()
        )

        try followingCollection(of: currentUserId)
            .document(target.id)
            .setData(from: relationship)

        AppLogger.firebase.info("Followed user: \(target.id)")
    }

    func unfollow(currentUserId: String, targetUserId: String) async throws {
        try await followingCollection(of: currentUserId)
            .document(targetUserId)
            .delete()

        AppLogger.firebase.info("Unfollowed user: \(targetUserId)")
    }

    // MARK: - Queries

    func isFollowing(currentUserId: String, targetUserId: String) async throws -> Bool {
        let snapshot = try await followingCollection(of: currentUserId)
            .document(targetUserId)
            .getDocument()
        return snapshot.exists
    }

    func getFollowing(of userId: String, limit: Int = 50) async throws -> [FollowRelationship] {
        let snapshot = try await followingCollection(of: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        let relationships = try snapshot.documents.compactMap { try $0.data(as: FollowRelationship.self) }
        return await hydrateUsers(relationships)
    }

    func getFollowers(of userId: String, limit: Int = 50) async throws -> [FollowRelationship] {
        let snapshot = try await followersCollection(of: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        let relationships = try snapshot.documents.compactMap { try $0.data(as: FollowRelationship.self) }
        return await hydrateUsers(relationships)
    }

    /// Refresh denormalized fields (displayName / photoURL / color) from the
    /// canonical user docs so list rows reflect renames and new profile photos
    /// without re-writing every follow record. Same pattern as FeedService.
    private func hydrateUsers(_ relationships: [FollowRelationship]) async -> [FollowRelationship] {
        let userIds = Array(Set(relationships.map { $0.userId }))
        guard !userIds.isEmpty else { return relationships }

        var userById: [String: User] = [:]

        // Firestore `in` queries cap at 30 values; chunk to stay safe.
        for chunkStart in stride(from: 0, to: userIds.count, by: 30) {
            let chunkEnd = min(chunkStart + 30, userIds.count)
            let chunk = Array(userIds[chunkStart..<chunkEnd])

            do {
                let snap = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                for doc in snap.documents {
                    if let user = try? doc.data(as: User.self) {
                        userById[user.id] = user
                    }
                }
            } catch {
                AppLogger.firebase.warning("Follow list user hydration failed: \(error.localizedDescription)")
                return relationships
            }
        }

        return relationships.map { rel in
            var copy = rel
            if let user = userById[rel.userId] {
                copy.displayName = user.displayName
                copy.photoURL = user.photoURL
                copy.color = user.color
            }
            return copy
        }
    }
}
