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
        seasonService: SeasonService = SeasonService()
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
        }

        // Add to route
        routePoints.append(point)
        previousRoutePoint = point

        // H3 zone tracking
        let h3Index = h3Service.h3Index(for: point.coordinate)
        currentH3Index = h3Index
        visitedZones.append(h3Index)

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

    // MARK: - Cleanup

    deinit {
        timer?.invalidate()
    }
}
