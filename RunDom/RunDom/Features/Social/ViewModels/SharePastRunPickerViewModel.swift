import SwiftUI
import FirebaseFirestore

/// Backs the feed's "share an older run" picker. Loads the current user's
/// runs (most recent first, paginated) so any past run can be turned into a
/// post, and tracks which ones are already shared so they can't be posted twice.
@MainActor
final class SharePastRunPickerViewModel: ObservableObject {

    // MARK: - Published State

    @Published var runs: [RunSession] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var errorMessage: String?

    // MARK: - Derived Lists

    /// Runs worth offering for sharing: real runs with a drawable route. This
    /// drops zero-distance / aborted "junk" runs (which also render as empty
    /// map thumbnails) so the picker only shows postable activity.
    private func isShareable(_ run: RunSession) -> Bool {
        run.distance > 0 && run.route.count >= 2
    }

    /// Shareable runs not yet posted — the primary section, shown prominently.
    var unsharedRuns: [RunSession] {
        runs.filter { isShareable($0) && $0.postId == nil }
    }

    /// Shareable runs already posted — kept for reference, shown dimmed.
    var sharedRuns: [RunSession] {
        runs.filter { isShareable($0) && $0.postId != nil }
    }

    /// True once a load has happened and nothing is left to offer.
    var hasNoShareableRuns: Bool {
        unsharedRuns.isEmpty && sharedRuns.isEmpty
    }

    // MARK: - Services

    private let firestoreService: FirestoreService
    private var lastDocument: DocumentSnapshot?

    private let pageSize = 20

    // MARK: - Init

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
    }

    // MARK: - Data Loading

    func loadInitial(userId: String) async {
        guard runs.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        lastDocument = nil

        do {
            let result = try await firestoreService.getRuns(userId: userId, limit: pageSize)
            runs = result.runs
            lastDocument = result.lastDocument
            hasMore = result.runs.count == pageSize
        } catch {
            AppLogger.firebase.error("Failed to load runs for sharing: \(error.localizedDescription)")
            errorMessage = "social.share.picker.error".localized
        }

        isLoading = false
    }

    func loadMore(userId: String) async {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true

        do {
            let result = try await firestoreService.getRuns(userId: userId, limit: pageSize, after: lastDocument)
            runs.append(contentsOf: result.runs)
            lastDocument = result.lastDocument
            hasMore = result.runs.count == pageSize
        } catch {
            AppLogger.firebase.error("Failed to load more runs for sharing: \(error.localizedDescription)")
        }

        isLoadingMore = false
    }

    /// Reflects a freshly published run locally so its row flips to the
    /// "already shared" state without a round-trip.
    func markShared(runId: String, postId: String) {
        guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }
        runs[index].postId = postId
    }
}
