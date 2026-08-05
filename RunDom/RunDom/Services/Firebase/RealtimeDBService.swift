import Foundation
import FirebaseDatabase

final class RealtimeDBService {
    struct CaptureTransactionResult {
        let captured: Bool
        let ownershipChanged: Bool
        let isNewTerritory: Bool
        let previousOwnerId: String?
        let previousOwnerColor: String?
        let remainingDefense: Double
    }

    private final class CaptureTransactionMetadata: @unchecked Sendable {
        private let lock = NSLock()
        private var isNewTerritory = false
        private var previousOwnerId: String?
        private var previousOwnerColor: String?
        private var ownershipChanged = false

        func update(
            isNewTerritory: Bool,
            previousOwnerId: String?,
            previousOwnerColor: String?,
            ownershipChanged: Bool
        ) {
            lock.lock()
            self.isNewTerritory = isNewTerritory
            self.previousOwnerId = previousOwnerId
            self.previousOwnerColor = previousOwnerColor
            self.ownershipChanged = ownershipChanged
            lock.unlock()
        }

        func snapshot() -> (
            isNewTerritory: Bool,
            previousOwnerId: String?,
            previousOwnerColor: String?,
            ownershipChanged: Bool
        ) {
            lock.lock()
            defer { lock.unlock() }
            return (
                isNewTerritory,
                previousOwnerId,
                previousOwnerColor,
                ownershipChanged
            )
        }
    }

    private let db: DatabaseReference

    private var territoryObservers: [String: DatabaseHandle] = [:]
    private let iso8601 = ISO8601DateFormatter()

    init() {
        // Resolve the database URL from the active Firebase app. Debug builds use
        // GoogleService-Info-Staging.plist; Release uses GoogleService-Info.plist.
        db = Database.database().reference()
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

    /// One-shot season read used by aggregate surfaces such as the leaderboard.
    func getTerritories(seasonId: String) async throws -> [Territory] {
        let snapshot = try await territoriesRef(seasonId: seasonId).getData()
        return snapshot.children.compactMap { child -> Territory? in
            guard let childSnapshot = child as? DataSnapshot,
                  let dict = childSnapshot.value as? [String: Any] else {
                return nil
            }
            return decodeTerritory(from: dict)
        }
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
    ) async throws -> CaptureTransactionResult {
        let appliedDistance = sanitizedCellDistance(distance)
        guard appliedDistance > 0 else {
            return CaptureTransactionResult(
                captured: false,
                ownershipChanged: false,
                isNewTerritory: false,
                previousOwnerId: nil,
                previousOwnerColor: nil,
                remainingDefense: 0
            )
        }

        let ref = territoryRef(seasonId: seasonId, h3Index: h3Index)
        let metadata = CaptureTransactionMetadata()

        let result = try await ref.runTransactionBlock { currentData in
            if var existingDict = currentData.value as? [String: Any] {
                let currentOwner = existingDict["ownerId"] as? String ?? ""
                let currentOwnerColor = existingDict["ownerColor"] as? String
                let storedDefense = self.numberAsDouble(existingDict["defenseLevel"]) ?? 0
                let lastRunDate = self.parseDate(existingDict["lastRunDate"]) ?? Date()
                let now = Date()
                let decayFactor = self.defenseDecayFactor(lastRunDate: lastRunDate, asOf: now)
                let effectiveDefense = storedDefense * decayFactor
                var ownershipChanged = false

                if currentOwner == userId {
                    // Reinforcement starts a fresh decay window from the already
                    // decayed defense instead of reviving the stale raw value.
                    existingDict["defenseLevel"] = effectiveDefense + appliedDistance
                    existingDict["totalDistance"] = (self.numberAsDouble(existingDict["totalDistance"]) ?? 0) + appliedDistance
                    existingDict["lastRunDate"] = ISO8601DateFormatter().string(from: now)
                } else {
                    // Attack the effective (time-decayed) defense. If the cell
                    // survives, convert the remaining effective value back to
                    // the original decay baseline so future reads/attacks apply
                    // decay exactly once.
                    let remainingEffectiveDefense = effectiveDefense - appliedDistance
                    if remainingEffectiveDefense <= 0 || decayFactor <= 0 {
                        // Captured!
                        existingDict["ownerId"] = userId
                        existingDict["ownerColor"] = userColor
                        existingDict["defenseLevel"] = abs(remainingEffectiveDefense)
                        existingDict["totalDistance"] = appliedDistance
                        existingDict["lastRunDate"] = ISO8601DateFormatter().string(from: now)
                        ownershipChanged = !currentOwner.isEmpty
                    } else {
                        existingDict["defenseLevel"] = remainingEffectiveDefense / decayFactor
                    }
                }
                metadata.update(
                    isNewTerritory: false,
                    previousOwnerId: currentOwner.isEmpty ? nil : currentOwner,
                    previousOwnerColor: currentOwnerColor,
                    ownershipChanged: ownershipChanged
                )
                currentData.value = existingDict
            } else {
                // New territory
                metadata.update(
                    isNewTerritory: true,
                    previousOwnerId: nil,
                    previousOwnerColor: nil,
                    ownershipChanged: false
                )
                currentData.value = [
                    "h3Index": h3Index,
                    "ownerId": userId,
                    "ownerColor": userColor,
                    "defenseLevel": appliedDistance,
                    "totalDistance": appliedDistance,
                    "lastRunDate": ISO8601DateFormatter().string(from: Date())
                ]
            }
            return TransactionResult.success(withValue: currentData)
        }

        let captured: Bool
        let remainingDefense: Double
        let (committed, snapshot) = result
        if let dict = snapshot.value as? [String: Any] {
            captured = committed && (dict["ownerId"] as? String) == userId
            if captured {
                remainingDefense = 0
            } else {
                let storedDefense = numberAsDouble(dict["defenseLevel"]) ?? 0
                let lastRunDate = parseDate(dict["lastRunDate"]) ?? Date()
                remainingDefense = storedDefense * defenseDecayFactor(
                    lastRunDate: lastRunDate,
                    asOf: Date()
                )
            }
        } else {
            captured = false
            remainingDefense = 0
        }
        let transactionMetadata = metadata.snapshot()

        AppLogger.firebase.info(
            "Territory \(h3Index): captured=\(captured) ownershipChanged=\(captured && transactionMetadata.ownershipChanged) by \(userId)"
        )
        return CaptureTransactionResult(
            captured: captured,
            ownershipChanged: captured && transactionMetadata.ownershipChanged,
            isNewTerritory: transactionMetadata.isNewTerritory,
            previousOwnerId: transactionMetadata.previousOwnerId,
            previousOwnerColor: transactionMetadata.previousOwnerColor,
            remainingDefense: remainingDefense
        )
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

    func deleteTerritoriesOwned(by userId: String) async throws -> Int {
        let snapshot = try await db.child("territories").getData()
        guard snapshot.exists() else { return 0 }

        var refsToDelete: [DatabaseReference] = []

        for seasonChild in snapshot.children {
            guard let seasonSnapshot = seasonChild as? DataSnapshot else { continue }

            for territoryChild in seasonSnapshot.children {
                guard let territorySnapshot = territoryChild as? DataSnapshot,
                      let dict = territorySnapshot.value as? [String: Any],
                      let ownerId = dict["ownerId"] as? String,
                      ownerId == userId else {
                    continue
                }
                refsToDelete.append(territorySnapshot.ref)
            }
        }

        for ref in refsToDelete {
            try await ref.setValue(NSNull())
        }

        if !refsToDelete.isEmpty {
            AppLogger.firebase.info("Deleted \(refsToDelete.count) territories for user \(userId)")
        }

        return refsToDelete.count
    }

    func updateTerritoryColorsOwned(by userId: String, newColor: String) async throws -> Int {
        let snapshot = try await db.child("territories").getData()
        guard snapshot.exists() else { return 0 }

        var refsToUpdate: [DatabaseReference] = []

        for seasonChild in snapshot.children {
            guard let seasonSnapshot = seasonChild as? DataSnapshot else { continue }

            for territoryChild in seasonSnapshot.children {
                guard let territorySnapshot = territoryChild as? DataSnapshot,
                      let dict = territorySnapshot.value as? [String: Any],
                      let ownerId = dict["ownerId"] as? String,
                      ownerId == userId else {
                    continue
                }
                refsToUpdate.append(territorySnapshot.ref.child("ownerColor"))
            }
        }

        for ref in refsToUpdate {
            try await ref.setValue(newColor)
        }

        if !refsToUpdate.isEmpty {
            AppLogger.firebase.info("Updated territory colors for \(refsToUpdate.count) territories of user \(userId)")
        }

        return refsToUpdate.count
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

    private func sanitizedCellDistance(_ distance: Double) -> Double {
        guard distance.isFinite, distance > 0 else { return 0 }
        return min(distance, AppConstants.Game.maxCellDistancePerRun)
    }

    private func defenseDecayFactor(lastRunDate: Date, asOf date: Date) -> Double {
        let hoursSinceLastRun = max(date.timeIntervalSince(lastRunDate) / 3600, 0)
        let decayHours = hoursSinceLastRun - Double(AppConstants.Game.defenseDecayHours)
        guard decayHours > 0 else { return 1 }
        return max(0, 1 - (decayHours / 168))
    }
}
