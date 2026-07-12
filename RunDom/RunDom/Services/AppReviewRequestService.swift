import Foundation

@MainActor
final class AppReviewRequestService {
    static let shared = AppReviewRequestService()

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func shouldRequestAfterSuccessfulRun(session: RunSession, currentUserBeforeSave: User) -> Bool {
        guard session.distance >= Self.minimumDistanceMeters,
              session.duration >= Self.minimumDurationSeconds,
              session.trail > 0 else {
            return false
        }

        let completedRunsAfterSave = currentUserBeforeSave.totalRuns + 1
        guard completedRunsAfterSave >= Self.minimumCompletedRuns else { return false }
        guard completedRunsAfterSave == Self.minimumCompletedRuns
                || completedRunsAfterSave.isMultiple(of: Self.runInterval) else {
            return false
        }

        if defaults.string(forKey: AppConstants.UserDefaultsKeys.appReviewLastRequestVersion) == appVersion {
            return false
        }

        if let lastRequestDate = defaults.object(
            forKey: AppConstants.UserDefaultsKeys.appReviewLastRequestDate
        ) as? Date,
           Date().timeIntervalSince(lastRequestDate) < Self.minimumSecondsBetweenRequests {
            return false
        }

        return true
    }

    func recordRequestAttempt() {
        defaults.set(Date(), forKey: AppConstants.UserDefaultsKeys.appReviewLastRequestDate)
        defaults.set(appVersion, forKey: AppConstants.UserDefaultsKeys.appReviewLastRequestVersion)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private static let minimumCompletedRuns = 3
    private static let runInterval = 5
    private static let minimumDistanceMeters: Double = 1_000
    private static let minimumDurationSeconds: TimeInterval = 5 * 60
    private static let minimumSecondsBetweenRequests: TimeInterval = 30 * 24 * 60 * 60
}
