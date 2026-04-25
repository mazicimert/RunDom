import SwiftUI
import Combine
import CoreLocation

@MainActor
final class ActiveRunViewModel: ObservableObject {

    // MARK: - Run State

    enum RunState: Equatable {
        case running
        case paused
        case finished
    }

    enum RivalTerritoryState: Equatable {
        case outside
        case inside(territory: Territory)
    }

    // MARK: - Published State

    @Published var runState: RunState = .running
    @Published var elapsedTime: TimeInterval = 0
    @Published var distance: Double = 0 // meters
    @Published var currentSpeed: Double = 0 // km/h
    @Published var avgSpeed: Double = 0 // km/h
    @Published var maxSpeed: Double = 0 // km/h
    @Published var routePoints: [RoutePoint] = []
    @Published var visitedZones: [String] = []
    @Published var uniqueZones: Set<String> = []
    @Published var territoriesCaptured: Int = 0
    @Published var territoryConquestAnimationTrigger: Int = 0
    @Published var isBoostActive: Bool = true
    @Published var gpsSignalLost = false
    @Published var currentH3Index: String?
    @Published var isRivalOverlayEnabled = false
    @Published private(set) var nearbyRivalTerritories: [Territory] = []
    @Published private(set) var currentRivalTerritoryState: RivalTerritoryState = .outside
    @Published var rivalTerritoryEntryTrigger: Int = 0

    // MARK: - Configuration

    let mode: RunMode
    let userId: String
    let userColor: String
    let userDisplayName: String?

    // MARK: - Services

    private let locationManager: LocationManager
    private let motionManager: MotionManager
    private let h3Service: H3GridService
    private let territoryService: TerritoryService
    private let territoryLossService: TerritoryLossService
    private let antiCheatService: AntiCheatService
    private let seasonService: SeasonService
    private let realtimeDB: RealtimeDBService

    // MARK: - Timer

    private var timer: Timer?
    private var startDate: Date
    private var pausedDuration: TimeInterval = 0
    private var pauseStartDate: Date?

    // MARK: - Tracking

    private var cancellables = Set<AnyCancellable>()
    private var previousRoutePoint: RoutePoint?
    private var speedSamples: [Double] = []
    private var currentSeasonId: String?
    private var lastMilestoneKm: Int = 0
    private var lastMilestoneElapsedTime: TimeInterval = 0
    private var rivalTerritoryObserverId: String?
    private var rivalTerritoryObserverSeasonId: String?
    private var observedSeasonTerritories: [Territory] = []
    private var lastAnnouncedRivalTerritoryId: String?

    // MARK: - Init

    init(
        mode: RunMode,
        userId: String,
        userColor: String,
        userDisplayName: String? = nil,
        locationManager: LocationManager,
        motionManager: MotionManager = MotionManager(),
        h3Service: H3GridService = .shared,
        territoryService: TerritoryService = TerritoryService(),
        territoryLossService: TerritoryLossService = TerritoryLossService(),
        antiCheatService: AntiCheatService = AntiCheatService(),
        seasonService: SeasonService = SeasonService(),
        realtimeDB: RealtimeDBService = RealtimeDBService()
    ) {
        self.mode = mode
        self.userId = userId
        self.userColor = userColor
        self.userDisplayName = userDisplayName
        self.locationManager = locationManager
        self.motionManager = motionManager
        self.h3Service = h3Service
        self.territoryService = territoryService
        self.territoryLossService = territoryLossService
        self.antiCheatService = antiCheatService
        self.seasonService = seasonService
        self.realtimeDB = realtimeDB
        self.startDate = Date()
        self.isBoostActive = mode == .boost
    }

    // MARK: - Start

    func startRun() {
        startDate = Date()
        locationManager.startTracking()
        motionManager.startMonitoring()
        startTimer()
        observeLocationUpdates()
        observeGPSSignal()
        loadSeason()
        AppLogger.run.info("Run started: mode=\(self.mode.rawValue)")
    }

    private func loadSeason() {
        Task {
            do {
                let season = try await seasonService.getOrCreateCurrentSeason()
                currentSeasonId = season.id
                startRivalTerritoryObservationIfNeeded()
            } catch {
                AppLogger.run.error("Failed to load season: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }
    }

    private func updateElapsedTime() {
        guard runState == .running else { return }
        elapsedTime = Date().timeIntervalSince(startDate) - pausedDuration
    }

    // MARK: - Location Observation

    private func observeLocationUpdates() {
        locationManager.routePointPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] routePoint in
                self?.processRoutePoint(routePoint)
            }
            .store(in: &cancellables)
    }

    private func observeGPSSignal() {
        locationManager.$gpsSignalLost
            .receive(on: DispatchQueue.main)
            .assign(to: &$gpsSignalLost)
    }

    // MARK: - Process Location

    private func processRoutePoint(_ point: RoutePoint) {
        guard runState == .running else { return }

        // Update speed
        let speedKmh = max(point.speed * 3.6, 0)
        currentSpeed = speedKmh
        speedSamples.append(speedKmh)
        avgSpeed = speedSamples.reduce(0, +) / Double(speedSamples.count)
        maxSpeed = max(maxSpeed, speedKmh)

        // Anti-cheat: GPS consistency
        if let prev = previousRoutePoint {
            let flags = antiCheatService.validateGPSConsistency(previous: prev, current: point)
            if flags.contains(.gpsAnomaly) {
                previousRoutePoint = point
                return // Skip anomalous point
            }

            // Calculate distance
            let segmentDistance = prev.coordinate.distance(to: point.coordinate)
            distance += segmentDistance
            triggerKilometerMilestoneIfNeeded()
        }

        // Add to route
        routePoints.append(point)
        previousRoutePoint = point

        // H3 zone tracking
        let previousH3Index = currentH3Index
        let h3Index = h3Service.h3Index(for: point.coordinate)
        currentH3Index = h3Index
        visitedZones.append(h3Index)

        if h3Index != previousH3Index {
            refreshNearbyRivalTerritories()
        }

        let isNewZone = !uniqueZones.contains(h3Index)
        uniqueZones.insert(h3Index)

        // Capture territory for new zones
        if isNewZone {
            captureZone(h3Index: h3Index, distance: 10) // Base distance for entering zone
        }

        // Boost speed check
        if mode == .boost && isBoostActive {
            if !antiCheatService.isBoostSpeedMet(currentSpeedKmh: avgSpeed) && elapsedTime > 120 {
                // Check after 2 min grace period
                isBoostActive = false
                AppLogger.run.info("Boost cancelled: avg speed \(self.avgSpeed) < threshold")
            }
        }
    }

    // MARK: - Kilometer Milestones

    private func triggerKilometerMilestoneIfNeeded() {
        let useMiles = UnitPreference.shared.useMiles
        let metersPerUnit = useMiles ? (1000.0 / UnitPreference.milesPerKilometer) : 1000.0
        let currentUnit = Int(distance / metersPerUnit)
        guard currentUnit > lastMilestoneKm else { return }
        let paceSecondsPerUnit = elapsedTime - lastMilestoneElapsedTime
        lastMilestoneKm = currentUnit
        lastMilestoneElapsedTime = elapsedTime
        Haptics.notification(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            Haptics.impact(.heavy)
        }
        RunAudioService.shared.announceKilometer(
            km: currentUnit,
            paceSecondsPerKm: paceSecondsPerUnit,
            useMiles: useMiles
        )
    }

    // MARK: - Territory Capture

    private func captureZone(h3Index: String, distance: Double) {
        guard let seasonId = currentSeasonId else { return }
        Task {
            do {
                let captured = try await territoryService.captureTerritory(
                    h3Index: h3Index,
                    userId: userId,
                    userColor: userColor,
                    distance: distance,
                    seasonId: seasonId
                )
                if captured.captured {
                    territoriesCaptured += 1
                }

                let conqueredFromOpponent = captured.captured
                    && (captured.previousOwnerId?.isEmpty == false)
                    && captured.previousOwnerId != userId

                if conqueredFromOpponent {
                    territoryConquestAnimationTrigger += 1
                    syncObservedTerritoryAfterCapture(h3Index: h3Index)

                    if let previousOwnerId = captured.previousOwnerId {
                        try? await territoryLossService.recordLossEvent(
                            losingUserId: previousOwnerId,
                            seasonId: seasonId,
                            h3Index: h3Index,
                            capturedByUserId: userId,
                            capturerDisplayName: userDisplayName
                        )
                    }
                }
            } catch {
                AppLogger.run.error("Territory capture failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Pause / Resume

    func pauseRun() {
        guard runState == .running else { return }
        runState = .paused
        pauseStartDate = Date()
        locationManager.stopTracking()
        motionManager.stopMonitoring()
        timer?.invalidate()
        AppLogger.run.info("Run paused at \(self.elapsedTime)s")
    }

    func resumeRun() {
        guard runState == .paused else { return }
        if let pauseStart = pauseStartDate {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        pauseStartDate = nil
        runState = .running
        locationManager.startTracking()
        motionManager.startMonitoring()
        startTimer()
        AppLogger.run.info("Run resumed")
    }

    // MARK: - Stop

    func stopRun() -> RunSession {
        runState = .finished
        timer?.invalidate()
        timer = nil
        locationManager.stopTracking()
        motionManager.stopMonitoring()
        cancellables.removeAll()
        lastMilestoneKm = 0
        lastMilestoneElapsedTime = 0
        stopRivalTerritoryObservation(clearToggleState: false)
        RunAudioService.shared.stopSpeaking()

        // Build session
        let session = RunSession(
            id: UUID().uuidString,
            userId: userId,
            mode: mode,
            startDate: startDate,
            endDate: Date(),
            distance: distance,
            avgSpeed: avgSpeed,
            maxSpeed: maxSpeed,
            trail: 0, // Calculated in PostRunViewModel
            territoriesCaptured: territoriesCaptured,
            uniqueZonesVisited: uniqueZones.count,
            totalZonesVisited: visitedZones.count,
            route: routePoints,
            isBoostActive: isBoostActive,
            seasonId: currentSeasonId
        )

        AppLogger.run.info("Run stopped: \(self.distance)m, \(self.elapsedTime)s, \(self.territoriesCaptured) territories")
        return session
    }

    // MARK: - Computed

    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) % 3600 / 60
        let seconds = Int(elapsedTime) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var distanceKm: Double {
        distance / 1000.0
    }

    var pace: String {
        avgSpeed.formattedPace
    }

    var boostSpeedStatus: BoostSpeedStatus {
        guard mode == .boost else { return .safe }
        let threshold = AppConstants.Game.boostMinSpeedKmh
        if currentSpeed >= threshold + 2 {
            return .safe
        } else if currentSpeed >= threshold {
            return .approaching
        }
        return .below
    }

    enum BoostSpeedStatus {
        case safe, approaching, below
    }

    // MARK: - Rival Territory Overlay

    func toggleRivalOverlay() {
        setRivalOverlayEnabled(!isRivalOverlayEnabled)
    }

    func setRivalOverlayEnabled(_ enabled: Bool) {
        guard enabled != isRivalOverlayEnabled else { return }

        isRivalOverlayEnabled = enabled

        if enabled {
            startRivalTerritoryObservationIfNeeded()
            refreshNearbyRivalTerritories()
        } else {
            stopRivalTerritoryObservation(clearToggleState: false)
        }
    }

    private func startRivalTerritoryObservationIfNeeded() {
        guard isRivalOverlayEnabled, let seasonId = currentSeasonId else { return }

        if rivalTerritoryObserverId != nil, rivalTerritoryObserverSeasonId == seasonId {
            refreshNearbyRivalTerritories()
            return
        }

        stopRivalTerritoryObservation(clearToggleState: false)

        rivalTerritoryObserverSeasonId = seasonId
        rivalTerritoryObserverId = realtimeDB.observeTerritories(seasonId: seasonId) { [weak self] territories in
            Task { @MainActor in
                guard let self else { return }
                self.observedSeasonTerritories = territories
                self.refreshNearbyRivalTerritories()
            }
        }
    }

    private func stopRivalTerritoryObservation(clearToggleState: Bool) {
        if let observerId = rivalTerritoryObserverId,
           let seasonId = rivalTerritoryObserverSeasonId {
            realtimeDB.removeObserver(id: observerId, seasonId: seasonId)
        }

        rivalTerritoryObserverId = nil
        rivalTerritoryObserverSeasonId = nil
        observedSeasonTerritories = []
        nearbyRivalTerritories = []
        currentRivalTerritoryState = .outside
        lastAnnouncedRivalTerritoryId = nil

        if clearToggleState {
            isRivalOverlayEnabled = false
        }
    }

    private func refreshNearbyRivalTerritories() {
        guard isRivalOverlayEnabled, let currentH3Index else {
            nearbyRivalTerritories = []
            currentRivalTerritoryState = .outside
            lastAnnouncedRivalTerritoryId = nil
            return
        }

        let nearbyIndices = h3Service.kRingIndices(
            forIndex: currentH3Index,
            ring: AppConstants.Location.rivalOverlayRing
        )

        let rivals = observedSeasonTerritories
            .filter { nearbyIndices.contains($0.h3Index) && $0.ownerId != userId }
            .sorted { $0.h3Index < $1.h3Index }

        nearbyRivalTerritories = rivals
        updateCurrentRivalTerritoryState(using: rivals, currentH3Index: currentH3Index)
    }

    private func updateCurrentRivalTerritoryState(using territories: [Territory], currentH3Index: String) {
        guard let territory = territories.first(where: { $0.h3Index == currentH3Index }) else {
            currentRivalTerritoryState = .outside
            lastAnnouncedRivalTerritoryId = nil
            return
        }

        currentRivalTerritoryState = .inside(territory: territory)

        if lastAnnouncedRivalTerritoryId != territory.h3Index {
            lastAnnouncedRivalTerritoryId = territory.h3Index
            rivalTerritoryEntryTrigger += 1
        }
    }

    private func syncObservedTerritoryAfterCapture(h3Index: String) {
        guard let index = observedSeasonTerritories.firstIndex(where: { $0.h3Index == h3Index }) else { return }
        observedSeasonTerritories[index].ownerId = userId
        observedSeasonTerritories[index].ownerColor = userColor
        observedSeasonTerritories[index].lastRunDate = Date()
        refreshNearbyRivalTerritories()
    }

    // MARK: - Cleanup

    deinit {
        timer?.invalidate()
        if let observerId = rivalTerritoryObserverId,
           let seasonId = rivalTerritoryObserverSeasonId {
            realtimeDB.removeObserver(id: observerId, seasonId: seasonId)
        }
    }
}
