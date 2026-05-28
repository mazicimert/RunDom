import Foundation
import FirebaseFirestore

// Live cache of who the current user has blocked AND who has blocked them.
// Views observe this to filter posts, comments, search results and UserProfile
// reactively — no manual refresh after a block/unblock.
@MainActor
final class BlockedUsersStore: ObservableObject {
    static let shared = BlockedUsersStore()

    @Published private(set) var blockedIds: Set<String> = []
    @Published private(set) var blockedByIds: Set<String> = []

    private let db = Firestore.firestore()
    private var blockedListener: ListenerRegistration?
    private var blockedByListener: ListenerRegistration?
    private var attachedUserId: String?

    // MARK: - Lifecycle

    func start(for userId: String) {
        // Already listening for this user — no-op.
        guard attachedUserId != userId else { return }

        stop()
        attachedUserId = userId

        blockedListener = db.collection("users")
            .document(userId)
            .collection("blocked")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    AppLogger.firebase.warning("blocked listener error: \(error.localizedDescription)")
                    return
                }
                let ids = snapshot?.documents.map(\.documentID) ?? []
                Task { @MainActor in
                    self.blockedIds = Set(ids)
                }
            }

        blockedByListener = db.collection("users")
            .document(userId)
            .collection("blockedBy")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    AppLogger.firebase.warning("blockedBy listener error: \(error.localizedDescription)")
                    return
                }
                let ids = snapshot?.documents.map(\.documentID) ?? []
                Task { @MainActor in
                    self.blockedByIds = Set(ids)
                }
            }
    }

    func stop() {
        blockedListener?.remove()
        blockedByListener?.remove()
        blockedListener = nil
        blockedByListener = nil
        attachedUserId = nil
        blockedIds = []
        blockedByIds = []
    }

    // MARK: - Queries

    func isBlocking(_ userId: String) -> Bool {
        blockedIds.contains(userId)
    }

    func isBlockedBy(_ userId: String) -> Bool {
        blockedByIds.contains(userId)
    }

    // Either direction — used for "should I filter this user out of feed/search?"
    func hasBlockRelationship(with userId: String) -> Bool {
        blockedIds.contains(userId) || blockedByIds.contains(userId)
    }
}
