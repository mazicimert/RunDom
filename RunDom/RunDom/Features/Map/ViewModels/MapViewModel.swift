import SwiftUI
import MapKit
import Combine

@MainActor
final class MapViewModel: ObservableObject {

    // MARK: - Published State

    @Published var territories: [Territory] = []
    @Published var dropzones: [Dropzone] = []
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTerritory: Territory?
    @Published var selectedDropzone: Dropzone?
    @Published var userTerritoryCount: Int = 0

    // MARK: - Services

    private let realtimeDB = RealtimeDBService()
    private let firestoreService = FirestoreService()
    private let h3Service = H3GridService.shared
    private let locationManager: LocationManager

    // MARK: - Private

    private var territoryObserverId: String?
    private var currentSeasonId: String?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        observeUserLocation()
    }

    // MARK: - Setup

    func onAppear(currentUser: User?) async {
        isLoading = true
        await loadCurrentSeason()
        observeTerritories()
        if let userId = currentUser?.id {
            updateUserTerritoryCount(userId: userId)
        }
        isLoading = false
    }

    func onDisappear() {
        removeObservers()
    }

    // MARK: - Location Observation

    private func observeUserLocation() {
        locationManager.$currentLocation
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.centerOnLocation(location.coordinate)
            }
            .store(in: &cancellables)

        if let lastKnown = locationManager.lastKnownCoordinate {
            centerOnLocation(lastKnown)
        }
    }

    func centerOnLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }

    func centerOnUser() {
        if let location = locationManager.currentLocation {
            centerOnLocation(location.coordinate)
        }
    }

    // MARK: - Season

    private func loadCurrentSeason() async {
        do {
            if let season = try await firestoreService.getCurrentSeason() {
                currentSeasonId = season.id
            } else {
                currentSeasonId = fallbackSeasonId()
            }
        } catch {
            AppLogger.firebase.error("Failed to load season: \(error.localizedDescription)")
            currentSeasonId = fallbackSeasonId()
        }
    }

    private func fallbackSeasonId() -> String {
        let calendar = Calendar.current
        let week = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.year, from: Date())
        return "season_\(year)_w\(week)"
    }

    // MARK: - Territory Observation

    private func observeTerritories() {
        guard let seasonId = currentSeasonId else { return }

        if let observerId = territoryObserverId {
            realtimeDB.removeObserver(id: observerId, seasonId: seasonId)
        }

        territoryObserverId = realtimeDB.observeTerritories(seasonId: seasonId) { [weak self] territories in
            Task { @MainActor in
                self?.territories = territories
            }
        }

        AppLogger.game.info("Observing territories for season: \(seasonId)")
    }

    private func removeObservers() {
        if let observerId = territoryObserverId, let seasonId = currentSeasonId {
            realtimeDB.removeObserver(id: observerId, seasonId: seasonId)
            territoryObserverId = nil
        }
    }

    // MARK: - User Territory Count

    func updateUserTerritoryCount(userId: String) {
        userTerritoryCount = territories.filter { $0.ownerId == userId }.count
    }

    // MARK: - Selection

    func selectTerritory(_ territory: Territory) {
        selectedTerritory = territory
        selectedDropzone = nil
    }

    func selectDropzone(_ dropzone: Dropzone) {
        selectedDropzone = dropzone
        selectedTerritory = nil
    }

    func clearSelection() {
        selectedTerritory = nil
        selectedDropzone = nil
    }

    func dismissError() {
        withAnimation(.easeOut(duration: AppConstants.Animation.quick)) {
            errorMessage = nil
        }
    }

    // MARK: - Visible Territories

    var visibleTerritories: [Territory] {
        let visibleIndices = Set(h3Service.cellIndices(in: region))
        return territories.filter { visibleIndices.contains($0.h3Index) }
    }

    var shouldRenderOverlays: Bool {
        h3Service.estimatedCellCount(in: region) < 5000
    }

    // MARK: - Helpers

    func ownerDisplayName(for territory: Territory, currentUser: User?) -> String {
        if territory.ownerId == currentUser?.id {
            return "map.myTerritory".localized
        }
        return territory.ownerId
    }
}

// MARK: - Color Hex Init

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}
