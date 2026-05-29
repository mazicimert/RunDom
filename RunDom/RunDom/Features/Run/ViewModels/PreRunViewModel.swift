import SwiftUI
import Combine
import CoreLocation

@MainActor
final class PreRunViewModel: ObservableObject {

    /// The "can I start a run right now?" gate, derived from permission + GPS readiness.
    /// Drives both the status line and the primary button's appearance/action.
    enum LocationGate: Equatable {
        case needsPermission   // not asked yet → request in-app
        case permissionDenied  // denied/restricted → deep-link to Settings
        case searching         // permitted, waiting for first GPS fix
        case ready             // good to go
    }

    // MARK: - Published State

    @Published var selectedMode: RunMode = .normal
    @Published var isLocationReady = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isStarting = false
    @Published var streakInfo: StreakService.StreakInfo?
    @Published var dailyChallengeState: DailyChallengeState?
    @Published var isLoadingChallenges = false
    @Published var isSelectingChallenge = false
    @Published var dailyChallengeReward: DailyChallengeReward?
    @Published var errorMessage: String?
    @Published var isChallengeSelectionPresented = false

    // MARK: - Services

    private let streakService: StreakService
    private let dailyChallengeService: DailyChallengeService
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        locationManager: LocationManager,
        streakService: StreakService = StreakService(),
        dailyChallengeService: DailyChallengeService = DailyChallengeService()
    ) {
        self.locationManager = locationManager
        self.streakService = streakService
        self.dailyChallengeService = dailyChallengeService
        observeLocation()
    }

    // MARK: - Location Readiness

    private func observeLocation() {
        locationManager.$currentLocation
            .map { $0 != nil }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLocationReady)

        locationManager.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$authorizationStatus)
    }

    var hasLocationPermission: Bool {
        locationManager.hasLocationPermission
    }

    var hasAlwaysPermission: Bool {
        locationManager.hasAlwaysPermission
    }

    /// Single source of truth for the primary button + status line.
    var locationGate: LocationGate {
        switch authorizationStatus {
        case .notDetermined:
            return .needsPermission
        case .denied, .restricted:
            return .permissionDenied
        default:
            return isLocationReady ? .ready : .searching
        }
    }

    /// Requests location permission in-app (When In Use is enough to start a run;
    /// the Always upgrade is handled separately once a run begins).
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Load Streak

    func load(user: User?) async {
        guard let user else { return }
        dailyChallengeReward = nil
        streakInfo = streakService.streakInfo(
            streakDays: user.streakDays,
            lastRunDate: user.lastRunDate
        )
        await loadDailyChallenges(userId: user.id)
        evaluateChallengeSelectionPresentation()
    }

    func loadDailyChallenges(userId: String) async {
        isLoadingChallenges = true
        defer { isLoadingChallenges = false }

        do {
            dailyChallengeState = try await dailyChallengeService.loadDailyState(userId: userId)
            errorMessage = nil
        } catch {
            AppLogger.firebase.error("Failed to load daily challenges: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func selectDailyChallenge(
        challengeId: String,
        userId: String
    ) async -> DailyChallengeService.SelectionResult? {
        guard !isSelectingChallenge else { return nil }
        isSelectingChallenge = true
        defer { isSelectingChallenge = false }

        do {
            let result = try await dailyChallengeService.selectChallenge(
                userId: userId,
                challengeId: challengeId
            )
            dailyChallengeState = result.state
            dailyChallengeReward = result.reward
            errorMessage = nil
            isChallengeSelectionPresented = false
            return result
        } catch {
            errorMessage = "error.generic".localized
            AppLogger.firebase.error("Failed to select daily challenge: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Mode Selection

    var boostThresholdText: String {
        let threshold = UnitPreference.speedValue(
            fromKilometersPerHour: AppConstants.Game.boostMinSpeedKmh,
            useMiles: UnitPreference.shared.useMiles
        )
        return "\(threshold.formattedDecimal(maxFractionDigits: 0)) \(UnitPreference.shared.speedUnitLabel)"
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
        errorMessage = nil
        return true
    }

    var selectedChallenge: DailyChallengeTemplate? {
        dailyChallengeState?.selectedChallenge
    }

    var hasSelectedChallenge: Bool {
        selectedChallenge != nil
    }

    func presentChallengeSelection() {
        guard dailyChallengeState != nil else { return }
        isChallengeSelectionPresented = true
    }

    func dismissChallengeSelection() {
        isChallengeSelectionPresented = false
    }

    private func evaluateChallengeSelectionPresentation() {
        guard let state = dailyChallengeState else {
            isChallengeSelectionPresented = false
            return
        }

        guard state.selectedChallenge == nil else {
            isChallengeSelectionPresented = false
            return
        }

        guard dailyChallengeService.shouldShowDailyPrompt() else { return }
        dailyChallengeService.markDailyPromptShown()
        isChallengeSelectionPresented = true
    }
}
