import Foundation
import FirebaseFirestore

final class UserSearchService {

    private let db = Firestore.firestore()

    private var usersCollection: CollectionReference {
        db.collection("users")
    }

    /// Prefix search by `displayNameLowercased`. The trailing `\u{f8ff}` is a
    /// high Unicode private-use code point — Firestore range scans up to it,
    /// matching any string that starts with `prefix`.
    func search(query: String, limit: Int = 20) async throws -> [User] {
        let prefix = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !prefix.isEmpty else { return [] }

        let snapshot = try await usersCollection
            .whereField("displayNameLowercased", isGreaterThanOrEqualTo: prefix)
            .whereField("displayNameLowercased", isLessThan: prefix + "\u{f8ff}")
            .order(by: "displayNameLowercased")
            .limit(to: limit)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: User.self) }
    }
}
