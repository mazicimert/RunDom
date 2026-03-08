import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published var gpsSignalLost = false

    // MARK: - Publishers

    /// Emits every valid location update during an active run.
    let locationPublisher = PassthroughSubject<CLLocation, Never>()

    /// Emits route points built from location updates.
    let routePointPublisher = PassthroughSubject<RoutePoint, Never>()

    // MARK: - Private

    private let manager = CLLocationManager()
    private var lastValidLocation: CLLocation?

    // MARK: - Init

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5  // meters
        manager.activityType = .fitness

        // Sync initial authorization status
        authorizationStatus = manager.authorizationStatus

        // Configure based on current authorization level
        configureForCurrentAuthorization()
    }

    // MARK: - Permissions

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    var hasLocationPermission: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    var hasAlwaysPermission: Bool {
        authorizationStatus == .authorizedAlways
    }

    // MARK: - Authorization Configuration

    /// Configures location manager settings based on the current authorization level.
    /// Background location updates are only enabled with `.authorizedAlways`.
    private func configureForCurrentAuthorization() {
        switch authorizationStatus {
        case .authorizedAlways:
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = false
            manager.showsBackgroundLocationIndicator = true
            manager.startUpdatingLocation()
            AppLogger.location.info(
                "Configured for Always authorization — background updates enabled")

        case .authorizedWhenInUse:
            manager.allowsBackgroundLocationUpdates = false
            manager.startUpdatingLocation()
            AppLogger.location.info(
                "Configured for When In Use authorization — foreground updates only")

        default:
            AppLogger.location.info("No location authorization — updates not started")
        }
    }

    // MARK: - Tracking

    func startTracking() {
        guard hasLocationPermission else {
            AppLogger.location.warning("Cannot start tracking — no location permission")
            return
        }
        isTracking = true
        gpsSignalLost = false
        lastValidLocation = nil
        configureForActiveTracking()
        manager.startUpdatingLocation()
        AppLogger.location.info("Location tracking started")
    }

    func stopTracking() {
        isTracking = false
        gpsSignalLost = false
        lastValidLocation = nil
        // Don't stop location updates entirely — keep passive updates
        // for map centering and pre-run readiness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 50  // Less frequent updates when not running
        AppLogger.location.info("Run tracking stopped, passive updates continue")
    }

    /// Restore high-accuracy settings for active run tracking
    private func configureForActiveTracking() {
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
    }

    // MARK: - Location Validation

    private func isValidLocation(_ location: CLLocation) -> Bool {
        // Reject invalid accuracy
        guard location.horizontalAccuracy >= 0,
            location.horizontalAccuracy < 50
        else {
            return false
        }

        // Reject obviously invalid speed (> 50 m/s ≈ 180 km/h)
        if location.speed > 50 {
            return false
        }

        return true
    }

    private func hasGPSGap(from previous: CLLocation, to current: CLLocation) -> Bool {
        let timeDelta = current.timestamp.timeIntervalSince(previous.timestamp)
        return timeDelta > AppConstants.Location.gpsGapThresholdSeconds
    }

    // MARK: - Last Known Location (UserDefaults)

    func saveLastKnownLocation() {
        guard let location = currentLocation else { return }
        UserDefaults.standard.set(
            location.coordinate.latitude, forKey: AppConstants.UserDefaultsKeys.lastKnownLatitude)
        UserDefaults.standard.set(
            location.coordinate.longitude, forKey: AppConstants.UserDefaultsKeys.lastKnownLongitude)
    }

    var lastKnownCoordinate: CLLocationCoordinate2D? {
        let lat = UserDefaults.standard.double(
            forKey: AppConstants.UserDefaultsKeys.lastKnownLatitude)
        let lon = UserDefaults.standard.double(
            forKey: AppConstants.UserDefaultsKeys.lastKnownLongitude)
        guard lat != 0, lon != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in
            for location in locations {
                guard isValidLocation(location) else { continue }

                // Check GPS gap
                if let last = lastValidLocation, hasGPSGap(from: last, to: location) {
                    AppLogger.location.warning(
                        "GPS gap detected: \(location.timestamp.timeIntervalSince(last.timestamp))s"
                    )
                    gpsSignalLost = true
                    // Reset — gap data is excluded
                    lastValidLocation = location
                    continue
                }

                gpsSignalLost = false
                currentLocation = location
                lastValidLocation = location

                if isTracking {
                    locationPublisher.send(location)

                    let routePoint = RoutePoint(location: location)
                    routePointPublisher.send(routePoint)
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let clError = error as? CLError, clError.code == .denied {
                AppLogger.location.error("Location permission denied")
                stopTracking()
            } else {
                AppLogger.location.error("Location error: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            AppLogger.location.info(
                "Authorization changed: \(manager.authorizationStatus.rawValue)")

            // Configure location updates based on new authorization level
            configureForCurrentAuthorization()
        }
    }
}
