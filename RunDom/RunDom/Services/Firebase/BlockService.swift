import Foundation
import FirebaseFirestore

final class BlockService {

    private let db = Firestore.firestore()

    private var usersCollection: CollectionReference {
        db.collection("users")
    }

    private func blockedCollection(of userId: String) -> CollectionReference {
        usersCollection.document(userId).collection("blocked")
    }

    private func blockedByCollection(of userId: String) -> CollectionReference {
        usersCollection.document(userId).collection("blockedBy")
    }

    // MARK: - Block / Unblock

    func block(currentUserId: String, target: User) async throws {
        guard currentUserId != target.id else { return }

        let relationship = BlockRelationship(
            userId: target.id,
            displayName: target.displayName,
            photoURL: target.photoURL,
            color: target.color,
            createdAt: Date()
        )

        try blockedCollection(of: currentUserId)
            .document(target.id)
            .setData(from: relationship)

        AppLogger.firebase.info("Blocked user: \(target.id)")
    }

    func unblock(currentUserId: String, targetUserId: String) async throws {
        try await blockedCollection(of: currentUserId)
            .document(targetUserId)
            .delete()

        AppLogger.firebase.info("Unblocked user: \(targetUserId)")
    }

    // MARK: - Queries

    func isBlocking(currentUserId: String, targetUserId: String) async throws -> Bool {
        let snapshot = try await blockedCollection(of: currentUserId)
            .document(targetUserId)
            .getDocument()
        return snapshot.exists
    }

    func isBlockedBy(currentUserId: String, targetUserId: String) async throws -> Bool {
        let snapshot = try await blockedByCollection(of: currentUserId)
            .document(targetUserId)
            .getDocument()
        return snapshot.exists
    }

    func getBlocked(of userId: String, limit: Int = 100) async throws -> [BlockRelationship] {
        let snapshot = try await blockedCollection(of: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        let relationships = try snapshot.documents.compactMap {
            try $0.data(as: BlockRelationship.self)
        }
        return await hydrateUsers(relationships)
    }

    // MARK: - Hydration

    private func hydrateUsers(_ relationships: [BlockRelationship]) async -> [BlockRelationship] {
        let userIds = Array(Set(relationships.map { $0.userId }))
        guard !userIds.isEmpty else { return relationships }

        var userById: [String: User] = [:]

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
                AppLogger.firebase.warning("Block list user hydration failed: \(error.localizedDescription)")
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
