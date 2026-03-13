import Foundation
import FirebaseDatabase

final class RealtimeDBService {
    private let db: DatabaseReference

    private var territoryObservers: [String: DatabaseHandle] = [:]
    private let iso8601 = ISO8601DateFormatter()

    init() {
        db = Database.database(url: AppConstants.Firebase.realtimeDBURL).reference()
    }

    // MARK: - Territory References

    private func territoriesRef(seasonId: String) -> DatabaseReference {
        db.child("territories").child(seasonId)
    }

    private func territoryRef(seasonId: String, h3Index: String) -> DatabaseReference {
        territoriesRef(seasonId: seasonId).child(h3Index)
    }

    // MARK: - Read Territory

    func getTerritory(seasonId: String, h3Index: String) async throws -> Territory? {
        let snapshot = try await territoryRef(seasonId: seasonId, h3Index: h3Index).getData()
        guard snapshot.exists(),
              let dict = snapshot.value as? [String: Any],
              let territory = decodeTerritory(from: dict) else {
            return nil
        }
        return territory
    }

    // MARK: - Write Territory

    func updateTerritory(_ territory: Territory, seasonId: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(territory)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        try await territoryRef(seasonId: seasonId, h3Index: territory.h3Index).setValue(dict)
    }

    // MARK: - Capture Territory (Transaction)

    func captureTerritory(
        seasonId: String,
        h3Index: String,
        userId: String,
        userColor: String,
        distance: Double
    ) async throws -> Bool {
        let ref = territoryRef(seasonId: seasonId, h3Index: h3Index)

        let result = try await ref.runTransactionBlock { currentData in
            if var existingDict = currentData.value as? [String: Any] {
                let currentOwner = existingDict["ownerId"] as? String ?? ""
                let currentDefense = existingDict["defenseLevel"] as? Double ?? 0

                if currentOwner == userId {
                    // Own territory — increase defense
                    existingDict["defenseLevel"] = currentDefense + distance
                    existingDict["totalDistance"] = (existingDict["totalDistance"] as? Double ?? 0) + distance
                    existingDict["lastRunDate"] = ISO8601DateFormatter().string(from: Date())
                } else {
                    // Enemy territory — attempt capture
                    let newDefense = currentDefense - distance
                    if newDefense <= 0 {
                        // Captured!
                        existingDict["ownerId"] = userId
                        existingDict["ownerColor"] = userColor
                        existingDict["defenseLevel"] = abs(newDefense)
                        existingDict["totalDistance"] = distance
                        existingDict["lastRunDate"] = ISO8601DateFormatter().string(from: Date())
                    } else {
                        existingDict["defenseLevel"] = newDefense
                    }
                }
                currentData.value = existingDict
            } else {
                // New territory
                currentData.value = [
                    "h3Index": h3Index,
                    "ownerId": userId,
                    "ownerColor": userColor,
                    "defenseLevel": distance,
                    "totalDistance": distance,
                    "lastRunDate": ISO8601DateFormatter().string(from: Date())
                ]
            }
            return TransactionResult.success(withValue: currentData)
        }

        let captured: Bool
        let (_, snapshot) = result
        if let dict = snapshot.value as? [String: Any] {
            captured = (dict["ownerId"] as? String) == userId
        } else {
            captured = false
        }

        AppLogger.firebase.info("Territory \(h3Index): captured=\(captured) by \(userId)")
        return captured
    }

    // MARK: - Observe Territories in Region

    func observeTerritories(
        seasonId: String,
        onUpdate: @escaping ([Territory]) -> Void
    ) -> String {
        let ref = territoriesRef(seasonId: seasonId)
        let observerId = UUID().uuidString

        let handle = ref.observe(.value) { snapshot in
            var territories: [Territory] = []
            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot,
                      let dict = childSnapshot.value as? [String: Any],
                      let territory = self.decodeTerritory(from: dict) else {
                    continue
                }
                territories.append(territory)
            }
            onUpdate(territories)
        }

        territoryObservers[observerId] = handle
        return observerId
    }

    func removeObserver(id: String, seasonId: String) {
        guard let handle = territoryObservers.removeValue(forKey: id) else { return }
        territoriesRef(seasonId: seasonId).removeObserver(withHandle: handle)
    }

    func removeAllObservers(seasonId: String) {
        for (_, handle) in territoryObservers {
            territoriesRef(seasonId: seasonId).removeObserver(withHandle: handle)
        }
        territoryObservers.removeAll()
    }

    // MARK: - User Territories

    func getUserTerritories(seasonId: String, userId: String) async throws -> [Territory] {
        let snapshot = try await territoriesRef(seasonId: seasonId)
            .queryOrdered(byChild: "ownerId")
            .queryEqual(toValue: userId)
            .getData()

        var territories: [Territory] = []
        for child in snapshot.children {
            guard let childSnapshot = child as? DataSnapshot,
                  let dict = childSnapshot.value as? [String: Any],
                  let territory = decodeTerritory(from: dict) else {
                continue
            }
            territories.append(territory)
        }
        return territories
    }

    // MARK: - Territory Decode

    private func decodeTerritory(from dict: [String: Any]) -> Territory? {
        guard let h3Index = dict["h3Index"] as? String,
              let ownerId = dict["ownerId"] as? String,
              let ownerColor = dict["ownerColor"] as? String,
              let defenseLevel = numberAsDouble(dict["defenseLevel"]),
              let lastRunDate = parseDate(dict["lastRunDate"]) else {
            return nil
        }

        let totalDistance = numberAsDouble(dict["totalDistance"]) ?? 0

        return Territory(
            h3Index: h3Index,
            ownerId: ownerId,
            ownerColor: ownerColor,
            defenseLevel: defenseLevel,
            lastRunDate: lastRunDate,
            totalDistance: totalDistance
        )
    }

    private func parseDate(_ value: Any?) -> Date? {
        if let date = value as? Date {
            return date
        }

        if let seconds = value as? Double {
            // Backward compatibility:
            // - >= 1_000_000_000 -> unix epoch seconds
            // - smaller positive values are likely Apple reference-date seconds
            if seconds >= 1_000_000_000 {
                return Date(timeIntervalSince1970: seconds)
            }
            if seconds > 0 {
                return Date(timeIntervalSinceReferenceDate: seconds)
            }
        }

        if let intSeconds = value as? Int {
            return parseDate(Double(intSeconds))
        }

        if let text = value as? String {
            if let date = iso8601.date(from: text) {
                return date
            }

            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fallback.date(from: text)
        }

        return nil
    }

    private func numberAsDouble(_ value: Any?) -> Double? {
        if let d = value as? Double {
            return d
        }
        if let i = value as? Int {
            return Double(i)
        }
        if let n = value as? NSNumber {
            return n.doubleValue
        }
        return nil
    }
}
