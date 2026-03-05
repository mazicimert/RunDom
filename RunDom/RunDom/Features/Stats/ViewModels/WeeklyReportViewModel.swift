import SwiftUI

@MainActor
final class WeeklyReportViewModel: ObservableObject {

    // MARK: - Published State

    @Published var reports: [WeeklyReport] = []
    @Published var isLoading = false

    // MARK: - Services

    private let firestoreService: FirestoreService

    // MARK: - Init

    init(firestoreService: FirestoreService = FirestoreService()) {
        self.firestoreService = firestoreService
    }

    // MARK: - Computed

    var latestReport: WeeklyReport? {
        reports.first
    }

    // MARK: - Data Loading

    func loadReports(userId: String) async {
        isLoading = true

        do {
            reports = try await firestoreService.getWeeklyReports(userId: userId, limit: 10)
        } catch {
            AppLogger.firebase.error("Failed to load weekly reports: \(error.localizedDescription)")
        }

        isLoading = false
    }
}
