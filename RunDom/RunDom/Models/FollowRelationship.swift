import Foundation

// Stored at both:
//   users/{uid}/following/{targetUserId} → userId = targetUserId
//   users/{uid}/followers/{sourceUserId} → userId = sourceUserId
struct FollowRelationship: Codable, Identifiable, Equatable, Hashable {
    let userId: String
    var displayName: String
    var photoURL: String?
    // Not persisted on the Firestore doc — populated at read time by
    // FollowService when hydrating from the canonical user. Stays nil for
    // older docs that haven't been re-fetched yet.
    var color: String?
    let createdAt: Date

    var id: String { userId }
}
