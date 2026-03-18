import Foundation

final class TerritoryLossService {

    private let firestoreService: FirestoreService
    private let seasonService: SeasonService

    init(
        firestoreService: FirestoreService = FirestoreService(),
        seasonService: SeasonService = SeasonService()
    ) {
        self.firestoreService = firestoreService
        self.seasonService = seasonService
    }

    func recordLossEvent(
        losingUserId: String,
        seasonId: String,
        h3Index: String,
        capturedByUserId: String,
        capturerDisplayName: String?
    ) async throws {
        let normalizedLosingUserId = losingUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLosingUserId.isEmpty, normalizedLosingUserId != capturedByUserId else { return }

        let event = TerritoryLossEvent(
            id: UUID().uuidString,
            seasonId: seasonId,
            h3Index: h3Index,
            capturedAt: Date(),
            capturedByUserId: capturedByUserId,
            capturerDisplayName: capturerDisplayName,
            isSeen: false,
            seenAt: nil
        )

        try await firestoreService.saveTerritoryLossEvent(event, userId: normalizedLosingUserId)
    }

    func loadUnreadLossEvents(userId: String) async throws -> [TerritoryLossEvent] {
        let season = try await seasonService.getOrCreateCurrentSeason()
        return try await firestoreService.getUnreadTerritoryLossEvents(
            userId: userId,
            seasonId: season.id
        )
    }

    func markLossEventsSeen(userId: String, eventIds: [String]) async throws {
        guard !eventIds.isEmpty else { return }
        try await firestoreService.markTerritoryLossEventsSeen(userId: userId, eventIds: eventIds)
    }
}
