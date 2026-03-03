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
        return try snapshot.data(as: User.self)
    }

    func updateUser(_ user: User) async throws {
        try usersCollection.document(user.id).setData(from: user, merge: true)
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

    // MARK: - Leaderboard

    func getLeaderboard(scope: LeaderboardScope, seasonId: String, neighborhood: String? = nil, limit: Int = 50) async throws -> [LeaderboardEntry] {
        var query: Query = leaderboardCollection
            .whereField("seasonId", isEqualTo: seasonId)
            .order(by: "trail", descending: true)
            .limit(to: limit)

        if scope == .neighborhood, let hood = neighborhood {
            query = leaderboardCollection
                .whereField("seasonId", isEqualTo: seasonId)
                .whereField("neighborhood", isEqualTo: hood)
                .order(by: "trail", descending: true)
                .limit(to: limit)
        }

        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: LeaderboardEntry.self) }
    }

    func updateLeaderboardEntry(_ entry: LeaderboardEntry) async throws {
        try leaderboardCollection.document(entry.id).setData(from: entry, merge: true)
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

    // MARK: - Batch Updates

    func incrementUserTrail(userId: String, trail: Double, distance: Double) async throws {
        try await usersCollection.document(userId).updateData([
            "totalTrail": FieldValue.increment(trail),
            "totalDistance": FieldValue.increment(distance),
            "totalRuns": FieldValue.increment(Int64(1)),
            "currentSeasonTrail": FieldValue.increment(trail),
            "lastRunDate": Date()
        ])
    }
}
