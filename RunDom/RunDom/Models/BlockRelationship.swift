import Foundation

// Stored at both:
//   users/{uid}/blocked/{targetUserId}    → userId = targetUserId
//   users/{uid}/blockedBy/{sourceUserId}  → userId = sourceUserId (Cloud Function fan-out)
//
// Mirrors FollowRelationship shape so list rows render identically.
struct BlockRelationship: Codable, Identifiable, Equatable, Hashable {
    let userId: String
    var displayName: String
    var photoURL: String?
    // Hydrated at read time from the canonical user doc; nil on older docs.
    var color: String?
    let createdAt: Date

    var id: String { userId }
}
