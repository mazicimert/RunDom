import Foundation
import FirebaseFirestore

// Live cache of the current user's privacy zones. PostService consults this
// synchronously when sampling route previews — Firestore round-trip per post
// would be wasteful and racy.
@MainActor
final class PrivacyZonesStore: ObservableObject {
    static let shared = PrivacyZonesStore()

    @Published private(set) var zones: [PrivacyZone] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var attachedUserId: String?

    func start(for userId: String) {
        guard attachedUserId != userId else { return }
        stop()
        attachedUserId = userId

        listener = db.collection("users")
            .document(userId)
            .collection("privacyZones")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    AppLogger.firebase.warning("privacyZones listener error: \(error.localizedDescription)")
                    return
                }
                let docs = snapshot?.documents ?? []
                let parsed = docs.compactMap { try? $0.data(as: PrivacyZone.self) }
                Task { @MainActor in
                    self.zones = parsed
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        attachedUserId = nil
        zones = []
    }

    // MARK: - Masking

    /// Returns true if the given lat/lon is inside ANY of the user's zones.
    func isInsideAnyZone(latitude: Double, longitude: Double) -> Bool {
        zones.contains { $0.contains(latitude: latitude, longitude: longitude) }
    }

    var isEmpty: Bool { zones.isEmpty }
}
