import SwiftUI
import FirebaseFirestore

@MainActor
final class RunHistoryViewModel: ObservableObject {

    // MARK: - Published State

    @Published var runs: [RunSession] = []
    @Published var isLoading = false
    @Published var hasMore = true

    // MARK: - Services

    private let firestoreService: FirestoreService
    private var lastDocument: DocumentSnapshot?

    // MARK: - Init

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
    }

    // MARK: - Data Loading

    func loadRuns(userId: String) async {
        isLoading = true
        lastDocument = nil

        do {
            let result = try await firestoreService.getRuns(userId: userId, limit: 20)
            runs = result.runs
            lastDocument = result.lastDocument
            hasMore = result.runs.count == 20
        } catch {
            AppLogger.firebase.error("Failed to load run history: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func loadMore(userId: String) async {
        guard hasMore, !isLoading else { return }
        isLoading = true

        do {
            let result = try await firestoreService.getRuns(userId: userId, limit: 20, after: lastDocument)
            runs.append(contentsOf: result.runs)
            lastDocument = result.lastDocument
            hasMore = result.runs.count == 20
        } catch {
            AppLogger.firebase.error("Failed to load more runs: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func deleteRun(_ run: RunSession) async throws {
        try await firestoreService.deleteRun(run)
        runs.removeAll { $0.id == run.id }
    }
}
