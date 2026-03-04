import SwiftUI
import Combine

@MainActor
final class PreRunViewModel: ObservableObject {

    // MARK: - Published State

    @Published var selectedMode: RunMode = .normal
    @Published var isLocationReady = false
    @Published var isStarting = false
    @Published var streakInfo: StreakService.StreakInfo?
    @Published var errorMessage: String?

    // MARK: - Services

    private let streakService: StreakService
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(locationManager: LocationManager, streakService: StreakService = StreakService()) {
        self.locationManager = locationManager
        self.streakService = streakService
        observeLocation()
    }

    // MARK: - Location Readiness

    private func observeLocation() {
        locationManager.$currentLocation
            .map { $0 != nil }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLocationReady)
    }

    var hasLocationPermission: Bool {
        locationManager.hasLocationPermission
    }

    // MARK: - Load Streak

    func loadStreakInfo(user: User?) {
        guard let user else { return }
        streakInfo = streakService.streakInfo(
            streakDays: user.streakDays,
            lastRunDate: user.lastRunDate
        )
    }

    // MARK: - Mode Selection

    var boostThresholdText: String {
        String(format: "%.0f km/h", AppConstants.Game.boostMinSpeedKmh)
    }

    var boostMultiplierText: String {
        String(format: "%.0fx", AppConstants.Game.boostModeMultiplier)
    }

    // MARK: - Start Run

    func canStartRun() -> Bool {
        guard hasLocationPermission else {
            errorMessage = "run.noLocation".localized
            return false
        }
        guard isLocationReady else {
            errorMessage = "run.waitingGPS".localized
            return false
        }
        return true
    }
}
