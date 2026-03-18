import SwiftUI

@MainActor
final class AppRouter: ObservableObject {

    // MARK: - Navigation

    @Published var selectedTab: Tab = .map
    @Published var navigationPath = NavigationPath()

    // MARK: - Sheets

    @Published var presentedSheet: Sheet?
    @Published var isRunActive = false

    // MARK: - Tab

    enum Tab: Int, CaseIterable, Identifiable {
        case map
        case leaderboard
        case run
        case stats
        case profile

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .map: return "tab.map".localized
            case .leaderboard: return "tab.leaderboard".localized
            case .run: return "tab.run".localized
            case .stats: return "tab.stats".localized
            case .profile: return "tab.profile".localized
            }
        }

        var icon: String {
            switch self {
            case .map: return "map.fill"
            case .leaderboard: return "trophy.fill"
            case .run: return "figure.run"
            case .stats: return "chart.bar.fill"
            case .profile: return "person.fill"
            }
        }
    }

    // MARK: - Sheet

    enum Sheet: Identifiable {
        case runSession
        case postRunSummary(runId: String)
        case territoryDetail(territoryId: String)
        case dropzoneDetail(dropzoneId: String)
        case badgeDetail(badge: Badge)
        case editProfile
        case settings

        var id: String {
            switch self {
            case .runSession: return "runSession"
            case .postRunSummary(let id): return "postRunSummary-\(id)"
            case .territoryDetail(let id): return "territoryDetail-\(id)"
            case .dropzoneDetail(let id): return "dropzoneDetail-\(id)"
            case .badgeDetail(let badge): return "badgeDetail-\(badge.id)"
            case .editProfile: return "editProfile"
            case .settings: return "settings"
            }
        }
    }

    // MARK: - Actions

    func startRun() {
        isRunActive = true
        presentedSheet = .runSession
    }

    func endRun(runId: String) {
        isRunActive = false
        presentedSheet = .postRunSummary(runId: runId)
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func resetNavigation() {
        navigationPath = NavigationPath()
    }

    // MARK: - Notification Deep-link

    func handleNotificationDestination(_ destination: NotificationDestination) {
        switch destination {
        case .map, .territory, .dropzone:
            selectedTab = .map
        case .run, .dailyChallenge:
            selectedTab = .run
        case .profile:
            selectedTab = .profile
        }
    }
}
