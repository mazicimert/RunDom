import Foundation
import FirebaseFirestore

final class PrivacyZoneService {

    private let db = Firestore.firestore()

    private func collection(for userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("privacyZones")
    }

    // MARK: - CRUD

    @discardableResult
    func createZone(
        userId: String,
        name: String?,
        latitude: Double,
        longitude: Double,
        radius: Double
    ) async throws -> PrivacyZone {
        let id = UUID().uuidString
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = (trimmedName?.isEmpty == false) ? trimmedName : nil
        let clampedRadius = min(
            max(radius, PrivacyZoneConstants.minRadius),
            PrivacyZoneConstants.maxRadius
        )

        let zone = PrivacyZone(
            id: id,
            name: resolvedName,
            centerLatitude: latitude,
            centerLongitude: longitude,
            radius: clampedRadius,
            createdAt: Date()
        )

        try collection(for: userId).document(id).setData(from: zone)
        AppLogger.firebase.info("Privacy zone created: \(id) for \(userId)")
        return zone
    }

    func updateZone(userId: String, zone: PrivacyZone) async throws {
        try collection(for: userId).document(zone.id).setData(from: zone)
    }

    func deleteZone(userId: String, zoneId: String) async throws {
        try await collection(for: userId).document(zoneId).delete()
        AppLogger.firebase.info("Privacy zone deleted: \(zoneId)")
    }

    func getZones(userId: String) async throws -> [PrivacyZone] {
        let snap = try await collection(for: userId)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return try snap.documents.compactMap {
            try $0.data(as: PrivacyZone.self)
        }
    }
}
