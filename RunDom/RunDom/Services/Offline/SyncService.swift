import Foundation
import Network
import Combine

/// Monitors network connectivity and syncs pending offline data to Firebase
/// when the connection is restored.
final class SyncService: ObservableObject {

    // MARK: - Singleton

    static let shared = SyncService()

    // MARK: - Published State

    @Published private(set) var isOnline = true
    @Published private(set) var isSyncing = false
    @Published private(set) var pendingItemCount = 0

    // MARK: - Services

    private let offlineStorage: OfflineStorageService
    private let firestoreService: FirestoreService
    private let realtimeDB: RealtimeDBService
    private let streakService: StreakService

    // MARK: - Network Monitor

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mertmazici.RunDom.networkMonitor")

    // MARK: - Configuration

    private let maxRetries = 5

    private init(
        offlineStorage: OfflineStorageService = .shared,
        firestoreService: FirestoreService = FirestoreService(),
        realtimeDB: RealtimeDBService = RealtimeDBService(),
        streakService: StreakService = StreakService()
    ) {
        self.offlineStorage = offlineStorage
        self.firestoreService = firestoreService
        self.realtimeDB = realtimeDB
        self.streakService = streakService
    }

    // MARK: - Start / Stop

    /// Starts monitoring network connectivity.
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let online = path.status == .satisfied
            DispatchQueue.main.async {
                let wasOffline = !self.isOnline
                self.isOnline = online

                if online && wasOffline {
                    AppLogger.sync.info("Network restored, starting sync")
                    Task { await self.syncPendingItems() }
                }

                if !online {
                    AppLogger.sync.info("Network lost")
                }
            }
        }
        monitor.start(queue: monitorQueue)
        updatePendingCount()
        AppLogger.sync.info("Network monitoring started")
    }

    /// Stops monitoring network connectivity.
    func stopMonitoring() {
        monitor.cancel()
        AppLogger.sync.info("Network monitoring stopped")
    }

    // MARK: - Sync

    /// Attempts to sync all pending offline data to Firebase.
    func syncPendingItems() async {
        guard isOnline, !isSyncing else { return }

        await MainActor.run { isSyncing = true }

        await syncPendingRuns()
        await syncPendingCaptures()

        await MainActor.run {
            isSyncing = false
            updatePendingCount()
        }
    }

    // MARK: - Save with Fallback

    /// Saves a run to Firebase, falling back to offline storage if the network is unavailable.
    func saveRun(_ session: RunSession, user: User) async -> Bool {
        guard isOnline else {
            return saveRunOffline(session)
        }

        do {
            try await firestoreService.saveRun(session)
            try await firestoreService.incrementUserTrail(
                userId: user.id,
                trail: session.trail,
                distance: session.distance
            )

            let newStreakDays = streakService.updateStreak(
                currentStreakDays: user.streakDays,
                lastRunDate: user.lastRunDate
            )
            try await streakService.saveStreakUpdate(userId: user.id, newStreakDays: newStreakDays)

            AppLogger.sync.info("Run saved online: \(session.id)")
            return true
        } catch {
            AppLogger.sync.error("Online save failed, saving offline: \(error.localizedDescription)")
            return saveRunOffline(session)
        }
    }

    /// Captures a territory, falling back to offline storage if the network is unavailable.
    func captureTerritory(
        h3Index: String,
        userId: String,
        userColor: String,
        distance: Double,
        seasonId: String
    ) async -> Bool {
        guard isOnline else {
            return saveCaptureOffline(
                h3Index: h3Index,
                userId: userId,
                userColor: userColor,
                distance: distance,
                seasonId: seasonId
            )
        }

        do {
            _ = try await realtimeDB.captureTerritory(
                seasonId: seasonId,
                h3Index: h3Index,
                userId: userId,
                userColor: userColor,
                distance: distance
            )
            return true
        } catch {
            AppLogger.sync.error("Online capture failed, saving offline: \(error.localizedDescription)")
            return saveCaptureOffline(
                h3Index: h3Index,
                userId: userId,
                userColor: userColor,
                distance: distance,
                seasonId: seasonId
            )
        }
    }

    // MARK: - Private — Sync Runs

    private func syncPendingRuns() async {
        do {
            let pendingRuns = try offlineStorage.getPendingRuns()
            guard !pendingRuns.isEmpty else { return }

            AppLogger.sync.info("Syncing \(pendingRuns.count) pending runs")

            for pending in pendingRuns {
                guard pending.retryCount < maxRetries else {
                    AppLogger.sync.warning("Run \(pending.id) exceeded max retries, removing")
                    try? offlineStorage.removePendingRun(id: pending.id)
                    continue
                }

                do {
                    try await firestoreService.saveRun(pending.session)
                    try await firestoreService.incrementUserTrail(
                        userId: pending.session.userId,
                        trail: pending.session.trail,
                        distance: pending.session.distance
                    )
                    try offlineStorage.removePendingRun(id: pending.id)
                    AppLogger.sync.info("Synced pending run: \(pending.id)")
                } catch {
                    AppLogger.sync.error("Failed to sync run \(pending.id): \(error.localizedDescription)")
                    try? offlineStorage.incrementRetryCount(id: pending.id)
                }
            }
        } catch {
            AppLogger.sync.error("Failed to fetch pending runs: \(error.localizedDescription)")
        }
    }

    // MARK: - Private — Sync Captures

    private func syncPendingCaptures() async {
        do {
            let pendingCaptures = try offlineStorage.getPendingCaptures()
            guard !pendingCaptures.isEmpty else { return }

            AppLogger.sync.info("Syncing \(pendingCaptures.count) pending captures")

            for capture in pendingCaptures {
                guard capture.retryCount < maxRetries else {
                    AppLogger.sync.warning("Capture \(capture.captureId) exceeded max retries, removing")
                    try? offlineStorage.removePendingCapture(id: capture.captureId)
                    continue
                }

                do {
                    _ = try await realtimeDB.captureTerritory(
                        seasonId: capture.seasonId,
                        h3Index: capture.h3Index,
                        userId: capture.userId,
                        userColor: capture.userColor,
                        distance: capture.distance
                    )
                    try offlineStorage.removePendingCapture(id: capture.captureId)
                    AppLogger.sync.info("Synced pending capture: \(capture.h3Index)")
                } catch {
                    AppLogger.sync.error("Failed to sync capture \(capture.captureId): \(error.localizedDescription)")
                    try? offlineStorage.incrementCaptureRetryCount(id: capture.captureId)
                }
            }
        } catch {
            AppLogger.sync.error("Failed to fetch pending captures: \(error.localizedDescription)")
        }
    }

    // MARK: - Private — Offline Fallback

    private func saveRunOffline(_ session: RunSession) -> Bool {
        do {
            try offlineStorage.savePendingRun(session)
            updatePendingCount()
            return true
        } catch {
            AppLogger.sync.error("Failed to save run offline: \(error.localizedDescription)")
            return false
        }
    }

    private func saveCaptureOffline(
        h3Index: String,
        userId: String,
        userColor: String,
        distance: Double,
        seasonId: String
    ) -> Bool {
        do {
            try offlineStorage.savePendingCapture(
                h3Index: h3Index,
                userId: userId,
                userColor: userColor,
                distance: distance,
                seasonId: seasonId
            )
            updatePendingCount()
            return true
        } catch {
            AppLogger.sync.error("Failed to save capture offline: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private — Helpers

    private func updatePendingCount() {
        pendingItemCount = offlineStorage.pendingCount
    }
}
