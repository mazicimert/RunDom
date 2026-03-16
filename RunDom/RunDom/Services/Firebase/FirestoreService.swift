import Foundation
import FirebaseFirestore

final class FirestoreService {
    private let db = Firestore.firestore()

    // MARK: - Collection References

    private var usersCollection: CollectionReference { db.collection("users") }
    private var runsCollection: CollectionReference { db.collection("runs") }
    private var badgesCollection: CollectionReference { db.collection("badges") }
    private var leaderboardCollection: CollectionReference { db.collection("leaderboard") }
    private var seasonsCollection: CollectionReference { db.collection("seasons") }
    private var weeklyReportsCollection: CollectionReference { db.collection("weeklyReports") }
    private var dropzonesCollection: CollectionReference { db.collection("dropzones") }

    // MARK: - User

    func createUser(_ user: User) async throws {
        try usersCollection.document(user.id).setData(from: user)
        AppLogger.firebase.info("User created: \(user.id)")
    }

    func getUser(id: String) async throws -> User? {
        let snapshot = try await usersCollection.document(id).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: User.self)
    }

    func updateUser(_ user: User) async throws {
        try usersCollection.document(user.id).setData(from: user, merge: true)
    }

    func deleteUserAccountData(userId: String) async throws {
        try await deleteDocuments(in: runsCollection, whereField: "userId", equals: userId)
        try await deleteDocuments(in: leaderboardCollection, whereField: "userId", equals: userId)
        try await deleteDocuments(in: leaderboardCollection, whereField: "id", equals: userId)
        try? await leaderboardCollection.document(userId).delete()
        try await deleteDocuments(in: weeklyReportsCollection, whereField: "userId", equals: userId)
        try await deleteDocuments(in: badgesCollection, whereField: "userId", equals: userId)
        try await deleteAllDocuments(in: usersCollection.document(userId).collection("badges"))
        try await removeUserFromDropzoneClaims(userId: userId)
        try await usersCollection.document(userId).delete()
    }

    private func deleteDocuments(
        in collection: CollectionReference,
        whereField field: String,
        equals value: Any,
        batchSize: Int = 400
    ) async throws {
        while true {
            let snapshot = try await collection
                .whereField(field, isEqualTo: value)
                .limit(to: batchSize)
                .getDocuments()

            guard !snapshot.documents.isEmpty else { return }

            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()

            if snapshot.documents.count < batchSize {
                return
            }
        }
    }

    private func deleteAllDocuments(in collection: CollectionReference, batchSize: Int = 400) async throws {
        while true {
            let snapshot = try await collection.limit(to: batchSize).getDocuments()
            guard !snapshot.documents.isEmpty else { return }

            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()

            if snapshot.documents.count < batchSize {
                return
            }
        }
    }

    private func removeUserFromDropzoneClaims(userId: String, batchSize: Int = 200) async throws {
        while true {
            let snapshot = try await dropzonesCollection
                .whereField("claimedBy", arrayContains: userId)
                .limit(to: batchSize)
                .getDocuments()

            guard !snapshot.documents.isEmpty else { return }

            let batch = db.batch()
            for document in snapshot.documents {
                batch.updateData([
                    "claimedBy": FieldValue.arrayRemove([userId])
                ], forDocument: document.reference)
            }
            try await batch.commit()

            if snapshot.documents.count < batchSize {
                return
            }
        }
    }

    func updateUserNeighborhood(userId: String, neighborhood: String) async throws {
        let normalized = neighborhood.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        try await usersCollection.document(userId).updateData([
            "neighborhood": normalized
        ])
    }

    func userExists(id: String) async throws -> Bool {
        let snapshot = try await usersCollection.document(id).getDocument()
        return snapshot.exists
    }

    // MARK: - Runs

    func saveRun(_ run: RunSession) async throws {
        try runsCollection.document(run.id).setData(from: run)
        AppLogger.firebase.info("Run saved: \(run.id)")
    }

    func getRuns(userId: String, limit: Int = 20, after: DocumentSnapshot? = nil) async throws -> (runs: [RunSession], lastDocument: DocumentSnapshot?) {
        var query: Query = runsCollection
            .whereField("userId", isEqualTo: userId)
            .order(by: "startDate", descending: true)
            .limit(to: limit)

        if let lastDoc = after {
            query = query.start(afterDocument: lastDoc)
        }

        let snapshot = try await query.getDocuments()
        let runs = try snapshot.documents.compactMap { try $0.data(as: RunSession.self) }
        return (runs, snapshot.documents.last)
    }

    func getAllRuns(userId: String) async throws -> [RunSession] {
        let snapshot = try await runsCollection
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: RunSession.self) }
    }

    func getTodayTrail(userId: String) async throws -> Double {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        let snapshot = try await runsCollection
            .whereField("userId", isEqualTo: userId)
            .whereField("startDate", isGreaterThanOrEqualTo: startOfDay)
            .getDocuments()

        let runs = try snapshot.documents.compactMap { try $0.data(as: RunSession.self) }
        return runs.reduce(0) { $0 + $1.trail }
    }

    func deleteRun(_ run: RunSession) async throws {
        try await runsCollection.document(run.id).delete()

        var userUpdates: [String: Any] = [
            "totalTrail": FieldValue.increment(-run.trail),
            "totalDistance": FieldValue.increment(-run.distance),
            "totalRuns": FieldValue.increment(Int64(-1)),
            "currentSeasonTrail": FieldValue.increment(-run.trail)
        ]

        if let latestRunDate = try await latestRunStartDate(userId: run.userId) {
            userUpdates["lastRunDate"] = latestRunDate
        } else {
            userUpdates["lastRunDate"] = FieldValue.delete()
        }

        try await usersCollection.document(run.userId).updateData(userUpdates)
        AppLogger.firebase.info("Run deleted: \(run.id)")
    }

    private func latestRunStartDate(userId: String) async throws -> Date? {
        let snapshot = try await runsCollection
            .whereField("userId", isEqualTo: userId)
            .order(by: "startDate", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let latest = snapshot.documents.first else { return nil }

        if let timestamp = latest.data()["startDate"] as? Timestamp {
            return timestamp.dateValue()
        }

        return try? latest.data(as: RunSession.self).startDate
    }

    // MARK: - Badges

    func getBadges(userId: String) async throws -> [Badge] {
        let snapshot = try await usersCollection.document(userId)
            .collection("badges")
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Badge.self) }
    }

    func unlockBadge(_ badge: Badge, userId: String) async throws {
        var unlockedBadge = badge
        unlockedBadge.isUnlocked = true
        unlockedBadge.unlockedAt = Date()
        try usersCollection.document(userId)
            .collection("badges")
            .document(badge.id)
            .setData(from: unlockedBadge, merge: true)
        AppLogger.firebase.info("Badge unlocked: \(badge.id) for user: \(userId)")
    }

    func updateBadgeProgress(badgeId: String, userId: String, progress: Double) async throws {
        try await usersCollection.document(userId)
            .collection("badges")
            .document(badgeId)
            .updateData(["progress": progress])
    }

    func upsertBadge(_ badge: Badge, userId: String) async throws {
        try usersCollection.document(userId)
            .collection("badges")
            .document(badge.id)
            .setData(from: badge, merge: true)
    }

    // MARK: - Leaderboard

    func getLeaderboard(scope: LeaderboardScope, seasonId: String, neighborhood: String? = nil, limit: Int = 50) async throws -> [LeaderboardEntry] {
        let normalizedNeighborhood = neighborhood?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var query: Query = leaderboardCollection
            .whereField("seasonId", isEqualTo: seasonId)
            .order(by: "trail", descending: true)
            .limit(to: limit)

        if scope == .neighborhood, let hood = normalizedNeighborhood, !hood.isEmpty {
            query = leaderboardCollection
                .whereField("seasonId", isEqualTo: seasonId)
                .whereField("neighborhood", isEqualTo: hood)
                .order(by: "trail", descending: true)
                .limit(to: limit)
        }

        let snapshot = try await query.getDocuments()
        let entries = try snapshot.documents.compactMap { try $0.data(as: LeaderboardEntry.self) }

        // Fallback: some environments do not write to `leaderboard` yet.
        // In that case derive rankings from users' current season trail values.
        if !entries.isEmpty {
            let filteredEntries = await filterEntriesWithExistingUsers(entries)
            return assignRanks(filteredEntries)
        }

        let fallbackLimit = scope == .neighborhood ? max(limit * 4, 200) : limit
        let usersSnapshot = try await usersCollection
            .order(by: "currentSeasonTrail", descending: true)
            .limit(to: fallbackLimit)
            .getDocuments()

        let users = try usersSnapshot.documents.compactMap { try $0.data(as: User.self) }

        let filteredUsers: [User]
        if scope == .neighborhood {
            guard let hood = normalizedNeighborhood, !hood.isEmpty else {
                return []
            }

            filteredUsers = users.filter { user in
                user.totalRuns > 0 &&
                user.neighborhood?.trimmingCharacters(in: .whitespacesAndNewlines) == hood
            }
        } else {
            filteredUsers = users.filter { $0.totalRuns > 0 }
        }

        let effectiveSeasonId = seasonId.isEmpty ? generatedSeasonIdForCurrentWeek() : seasonId
        let derivedEntries = Array(filteredUsers.prefix(limit)).enumerated().map { index, user in
            LeaderboardEntry(
                id: user.id,
                userId: user.id,
                displayName: user.displayName,
                photoURL: user.photoURL,
                color: user.color,
                trail: user.currentSeasonTrail,
                rank: index + 1,
                neighborhood: user.neighborhood,
                seasonId: effectiveSeasonId,
                territoriesOwned: 0
            )
        }

        return derivedEntries
    }

    private func filterEntriesWithExistingUsers(_ entries: [LeaderboardEntry]) async -> [LeaderboardEntry] {
        let uniqueUserIds = Array(Set(entries.map(\.userId).filter { !$0.isEmpty }))
        guard !uniqueUserIds.isEmpty else { return entries }

        var existingUserIds = Set<String>()
        let chunkSize = 10
        var index = 0

        while index < uniqueUserIds.count {
            let end = min(index + chunkSize, uniqueUserIds.count)
            let chunk = Array(uniqueUserIds[index..<end])

            do {
                let snapshot = try await usersCollection
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                for document in snapshot.documents {
                    existingUserIds.insert(document.documentID)
                }
            } catch {
                AppLogger.firebase.warning("Failed to validate leaderboard users: \(error.localizedDescription)")
                return entries
            }

            index = end
        }

        let staleEntries = entries.filter { !existingUserIds.contains($0.userId) }
        if !staleEntries.isEmpty {
            await removeStaleLeaderboardEntries(staleEntries)
        }

        return entries.filter { existingUserIds.contains($0.userId) }
    }

    private func removeStaleLeaderboardEntries(_ staleEntries: [LeaderboardEntry]) async {
        let batch = db.batch()
        for entry in staleEntries {
            batch.deleteDocument(leaderboardCollection.document(entry.id))
        }

        do {
            try await batch.commit()
            AppLogger.firebase.info("Removed \(staleEntries.count) stale leaderboard entries")
        } catch {
            AppLogger.firebase.warning("Failed to remove stale leaderboard entries: \(error.localizedDescription)")
        }
    }

    func updateLeaderboardEntry(_ entry: LeaderboardEntry) async throws {
        try leaderboardCollection.document(entry.id).setData(from: entry, merge: true)
    }

    private func assignRanks(_ entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
        entries
            .sorted { $0.trail > $1.trail }
            .enumerated()
            .map { index, entry in
                LeaderboardEntry(
                    id: entry.id,
                    userId: entry.userId,
                    displayName: entry.displayName,
                    photoURL: entry.photoURL,
                    color: entry.color,
                    trail: entry.trail,
                    rank: index + 1,
                    neighborhood: entry.neighborhood,
                    seasonId: entry.seasonId,
                    territoriesOwned: entry.territoriesOwned
                )
            }
    }

    private func generatedSeasonIdForCurrentWeek() -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let now = Date()
        let weekNumber = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.yearForWeekOfYear, from: now)
        return "season_\(year)_w\(weekNumber)"
    }

    // MARK: - Seasons

    func getCurrentSeason() async throws -> Season? {
        let now = Date()
        let snapshot = try await seasonsCollection
            .whereField("startDate", isLessThanOrEqualTo: now)
            .whereField("endDate", isGreaterThan: now)
            .limit(to: 1)
            .getDocuments()
        return try snapshot.documents.first.flatMap { try $0.data(as: Season.self) }
    }

    // MARK: - Weekly Reports

    func saveWeeklyReport(_ report: WeeklyReport) async throws {
        try weeklyReportsCollection.document(report.id).setData(from: report)
    }

    func getWeeklyReports(userId: String, limit: Int = 10) async throws -> [WeeklyReport] {
        let snapshot = try await weeklyReportsCollection
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: WeeklyReport.self) }
    }

    // MARK: - Dropzones

    func getActiveDropzones() async throws -> [Dropzone] {
        let now = Date()
        let snapshot = try await dropzonesCollection
            .whereField("expirationDate", isGreaterThan: now)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Dropzone.self) }
    }

    func claimDropzone(dropzoneId: String, userId: String) async throws {
        let ref = dropzonesCollection.document(dropzoneId)
        try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(ref)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            guard var dropzone = try? snapshot.data(as: Dropzone.self) else { return nil }
            guard dropzone.canClaim(userId: userId) else { return nil }

            dropzone.claimedBy.append(userId)
            try? transaction.setData(from: dropzone, forDocument: ref)
            return nil
        }
        AppLogger.firebase.info("Dropzone claimed: \(dropzoneId) by \(userId)")
    }

    func getClaimedDropzoneCount(userId: String) async throws -> Int {
        let snapshot = try await dropzonesCollection
            .whereField("claimedBy", arrayContains: userId)
            .getDocuments()
        return snapshot.documents.count
    }

    // MARK: - Batch Updates

    func incrementUserTrail(userId: String, trail: Double, distance: Double, neighborhood: String? = nil) async throws {
        var updates: [String: Any] = [
            "totalTrail": FieldValue.increment(trail),
            "totalDistance": FieldValue.increment(distance),
            "totalRuns": FieldValue.increment(Int64(1)),
            "currentSeasonTrail": FieldValue.increment(trail),
            "lastRunDate": Date()
        ]

        if let neighborhood = neighborhood?.trimmingCharacters(in: .whitespacesAndNewlines),
           !neighborhood.isEmpty {
            updates["neighborhood"] = neighborhood
        }

        try await usersCollection.document(userId).updateData(updates)
    }
}
