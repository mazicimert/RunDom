import Foundation

@MainActor
final class UserSearchViewModel: ObservableObject {

    @Published var query: String = ""
    @Published var results: [User] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    private let searchService: UserSearchService
    private var searchTask: Task<Void, Never>?

    init(searchService: UserSearchService = UserSearchService()) {
        self.searchService = searchService
    }

    func onQueryChange(_ newValue: String) {
        searchTask?.cancel()

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            errorMessage = nil
            return
        }

        searchTask = Task {
            // 250ms debounce so we don't fire on every keystroke.
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            await performSearch(trimmed)
        }
    }

    private func performSearch(_ trimmed: String) async {
        isSearching = true
        errorMessage = nil
        do {
            results = try await searchService.search(query: trimmed, limit: 20)
        } catch {
            AppLogger.firebase.error("User search failed: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
            results = []
        }
        isSearching = false
    }
}
