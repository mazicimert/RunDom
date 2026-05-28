import Foundation

enum FollowListMode {
    case followers
    case following
}

@MainActor
final class FollowListViewModel: ObservableObject {

    @Published var entries: [FollowRelationship] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let userId: String
    let mode: FollowListMode

    private let followService: FollowService

    init(
        userId: String,
        mode: FollowListMode,
        followService: FollowService = FollowService()
    ) {
        self.userId = userId
        self.mode = mode
        self.followService = followService
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            switch mode {
            case .followers:
                entries = try await followService.getFollowers(of: userId)
            case .following:
                entries = try await followService.getFollowing(of: userId)
            }
        } catch {
            AppLogger.firebase.error("Follow list load failed: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
            entries = []
        }
        isLoading = false
    }
}
