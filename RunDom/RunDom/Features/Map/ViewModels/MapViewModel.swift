import SwiftUI
import MapKit
import Combine

enum TerritoryFilter: CaseIterable, Identifiable {
    case all
    case mine
    case rivals

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .all:
            return "map.filter.all"
        case .mine:
            return "map.filter.mine"
        case .rivals:
            return "map.filter.rivals"
        }
    }
}

enum CellOwnerState {
    case empty
    case mine
    case rival(territory: Territory)
}

struct CellInspection: Identifiable {
    let id: String
    let h3Index: String
    let coordinate: CLLocationCoordinate2D
    let distanceMeters: Double?
    let estimatedSeconds: Double?
    let ownerState: CellOwnerState
}

enum MapStyleOption: String, CaseIterable, Identifiable {
    case standard
    case hybrid
    case satellite

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .standard:
            return "map.style.standard"
        case .hybrid:
            return "map.style.hybrid"
        case .satellite:
            return "map.style.satellite"
        }
    }

    var mkMapType: MKMapType {
        switch self {
        case .standard:
            return .standard
        case .hybrid:
            return .hybrid
        case .satellite:
            return .satellite
        }
    }
}

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
    @Published var presentedTerritory: Territory?
    @Published var selectedDropzone: Dropzone?
    @Published var userTerritoryCount: Int = 0
    @Published var hasLoadedInitialTerritories = false
    @Published var territoryFilter: TerritoryFilter = .all
    @Published var mapStyle: MapStyleOption {
        didSet {
            guard mapStyle != oldValue else { return }
            UserDefaults.standard.set(
                mapStyle.rawValue,
                forKey: AppConstants.UserDefaultsKeys.mapStyle
            )
        }
    }
    @Published private(set) var selectedOwnerProfile: User?
    @Published var isHeatmapEnabled: Bool = false {
        didSet {
            guard isHeatmapEnabled != oldValue else { return }
            if isHeatmapEnabled {
                Task { await loadHeatmapIfNeeded() }
            }
        }
    }
    @Published private(set) var heatmapCells: [String: Int] = [:]
    @Published private(set) var isHeatmapLoading = false
    @Published var inspectedCell: CellInspection?
    @Published private(set) var inspectedOwnerDisplayName: String?

    // MARK: - Services

    private let realtimeDB = RealtimeDBService()
    private let firestoreService = FirestoreService()
    private let h3Service = H3GridService.shared
    private let locationManager: LocationManager

    // MARK: - Private

    private var territoryObserverId: String?
    private var currentSeasonId: String?
    private var currentUserId: String?
    private var cancellables = Set<AnyCancellable>()
    private var ownerProfilesById: [String: User] = [:]
    private var heatmapLoaded = false

    // MARK: - Init

    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        let savedRawValue = UserDefaults.standard.string(
            forKey: AppConstants.UserDefaultsKeys.mapStyle
        )
        self.mapStyle = savedRawValue.flatMap(MapStyleOption.init(rawValue:)) ?? .standard
        observeUserLocation()
    }

    // MARK: - Setup

    func onAppear(currentUser: User?) async {
        currentUserId = currentUser?.id
        if let currentUser {
            ownerProfilesById[currentUser.id] = currentUser
        }
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

    func zoomIn() {
        applyZoom(factor: 0.5)
    }

    func zoomOut() {
        applyZoom(factor: 2.0)
    }

    private func applyZoom(factor: Double) {
        let minSpan = 0.002
        let maxSpan = 180.0
        let newLat = min(max(region.span.latitudeDelta * factor, minSpan), maxSpan)
        let newLon = min(max(region.span.longitudeDelta * factor, minSpan), maxSpan)
        withAnimation(.easeInOut(duration: 0.25)) {
            region = MKCoordinateRegion(
                center: region.center,
                span: MKCoordinateSpan(latitudeDelta: newLat, longitudeDelta: newLon)
            )
        }
    }

    func focusTerritoryLoss(h3Index: String) {
        guard let coordinate = h3Service.coordinate(fromIndex: h3Index) else { return }

        clearSelection()

        withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.0032, longitudeDelta: 0.0032)
            )
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
        hasLoadedInitialTerritories = false

        if let observerId = territoryObserverId {
            realtimeDB.removeObserver(id: observerId, seasonId: seasonId)
        }

        territoryObserverId = realtimeDB.observeTerritories(seasonId: seasonId) { [weak self] territories in
            Task { @MainActor in
                self?.territories = territories
                self?.hasLoadedInitialTerritories = true
                self?.refreshSelection()
            }
        }

        AppLogger.game.info("Observing territories for season: \(seasonId)")
    }

    private func removeObservers() {
        if let observerId = territoryObserverId, let seasonId = currentSeasonId {
            realtimeDB.removeObserver(id: observerId, seasonId: seasonId)
            territoryObserverId = nil
        }
        hasLoadedInitialTerritories = false
    }

    // MARK: - User Territory Count

    func updateUserTerritoryCount(userId: String) {
        userTerritoryCount = territories.filter { $0.ownerId == userId }.count
    }

    // MARK: - Selection

    func selectTerritory(_ territory: Territory) {
        if selectedTerritory?.h3Index == territory.h3Index {
            presentSelectedTerritoryDetails()
            return
        }

        selectedTerritory = territory
        selectedDropzone = nil
        Task { await loadOwnerProfile(for: territory.ownerId) }
    }

    func selectDropzone(_ dropzone: Dropzone) {
        selectedDropzone = dropzone
        selectedTerritory = nil
        selectedOwnerProfile = nil
    }

    func clearSelection() {
        selectedTerritory = nil
        selectedDropzone = nil
        selectedOwnerProfile = nil
    }

    func presentSelectedTerritoryDetails() {
        guard let selectedTerritory else { return }
        presentedTerritory = selectedTerritory
    }

    // MARK: - Cell Inspection

    func inspectCell(at coordinate: CLLocationCoordinate2D, currentUser: User?) {
        let resolution = AppConstants.Location.h3Resolution
        let h3Index = coordinate.h3Index(resolution: resolution)
        let cellCoord = h3Service.coordinate(fromIndex: h3Index) ?? coordinate

        let userLocation = locationManager.currentLocation
        let distance: Double? = userLocation.map { loc in
            CLLocation(latitude: cellCoord.latitude, longitude: cellCoord.longitude)
                .distance(from: loc)
        }

        let paceSecondsPerKm = 3600.0 / 6.0
        let estimatedSeconds: Double? = distance.map { $0 / 1000.0 * paceSecondsPerKm }

        let ownerState: CellOwnerState
        if let territory = territories.first(where: { $0.h3Index == h3Index }) {
            if territory.ownerId == currentUser?.id {
                ownerState = .mine
            } else {
                ownerState = .rival(territory: territory)
            }
        } else {
            ownerState = .empty
        }

        inspectedCell = CellInspection(
            id: h3Index,
            h3Index: h3Index,
            coordinate: cellCoord,
            distanceMeters: distance,
            estimatedSeconds: estimatedSeconds,
            ownerState: ownerState
        )

        resolveInspectedOwnerName()
    }

    func dismissInspection() {
        inspectedCell = nil
        inspectedOwnerDisplayName = nil
    }

    private func resolveInspectedOwnerName() {
        guard let inspected = inspectedCell,
              case .rival(let territory) = inspected.ownerState else {
            inspectedOwnerDisplayName = nil
            return
        }

        if let cached = ownerProfilesById[territory.ownerId]?.displayName {
            inspectedOwnerDisplayName = cached
            return
        }

        inspectedOwnerDisplayName = nil
        Task { await fetchInspectedOwner(userId: territory.ownerId, h3Index: inspected.h3Index) }
    }

    private func fetchInspectedOwner(userId: String, h3Index: String) async {
        do {
            guard let user = try await firestoreService.getUser(id: userId) else { return }
            ownerProfilesById[userId] = user
            if inspectedCell?.h3Index == h3Index {
                inspectedOwnerDisplayName = user.displayName
            }
        } catch {
            AppLogger.firebase.error("Failed to load inspected owner: \(error.localizedDescription)")
        }
    }

    func openInspectedTerritoryDetails() {
        guard let inspected = inspectedCell else { return }

        switch inspected.ownerState {
        case .empty:
            return
        case .rival(let territory):
            presentedTerritory = territory
        case .mine:
            if let territory = territories.first(where: { $0.h3Index == inspected.h3Index }) {
                presentedTerritory = territory
            }
        }
    }

    func setTerritoryFilter(_ filter: TerritoryFilter) {
        territoryFilter = filter

        if let selectedTerritory,
           !filteredTerritories.contains(where: { $0.h3Index == selectedTerritory.h3Index }) {
            clearSelection()
        }
    }

    func refreshSelection() {
        if let selectedId = selectedTerritory?.h3Index {
            selectedTerritory = territories.first(where: { $0.h3Index == selectedId })
            if selectedTerritory == nil {
                selectedOwnerProfile = nil
            }
        }

        if let presentedId = presentedTerritory?.h3Index {
            presentedTerritory = territories.first(where: { $0.h3Index == presentedId })
        }
    }

    func dismissError() {
        withAnimation(.easeOut(duration: AppConstants.Animation.quick)) {
            errorMessage = nil
        }
    }

    // MARK: - Visible Territories

    var visibleTerritories: [Territory] {
        let visibleIndices = Set(h3Service.cellIndices(in: region))
        return filteredTerritories.filter { visibleIndices.contains($0.h3Index) }
    }

    var visibleHeatmapCells: [String: Int] {
        guard !heatmapCells.isEmpty else { return [:] }
        let visibleIndices = Set(h3Service.cellIndices(in: region))
        return heatmapCells.filter { visibleIndices.contains($0.key) }
    }

    var shouldRenderOverlays: Bool {
        h3Service.estimatedCellCount(in: region) < 5000
    }

    var filteredTerritories: [Territory] {
        switch territoryFilter {
        case .all:
            return territories
        case .mine:
            guard let currentUserId else { return territories }
            return territories.filter { $0.ownerId == currentUserId }
        case .rivals:
            guard let currentUserId else { return territories }
            return territories.filter { $0.ownerId != currentUserId }
        }
    }

    var selectedTerritoryOwnedCount: Int {
        guard let selectedTerritory else { return 0 }
        return territories.filter { $0.ownerId == selectedTerritory.ownerId }.count
    }

    var selectedTerritoryOwnerName: String {
        guard let selectedTerritory else { return "" }
        if selectedTerritory.ownerId == currentUserId {
            return "map.myTerritory".localized
        }
        return selectedOwnerProfile?.displayName ?? selectedTerritory.ownerId
    }

    var selectedTerritoryOwnerPhotoURL: String? {
        selectedOwnerProfile?.photoURL
    }

    var selectedTerritoryLastActiveText: String {
        selectedTerritory?.lastRunDate.relativeFormatted() ?? ""
    }

    var selectedTerritoryIsCurrentUserOwned: Bool {
        selectedTerritory?.ownerId == currentUserId
    }

    var selectedTerritoryOwnerNeighborhood: String? {
        selectedOwnerProfile?.neighborhood
    }

    // MARK: - Helpers

    func ownerDisplayName(for territory: Territory, currentUser: User?) -> String {
        if territory.ownerId == currentUser?.id {
            return "map.myTerritory".localized
        }
        return territory.ownerId
    }

    // MARK: - Heatmap

    func invalidateHeatmapCache() {
        heatmapLoaded = false
        heatmapCells = [:]
        if isHeatmapEnabled {
            Task { await loadHeatmapIfNeeded() }
        }
    }

    private func loadHeatmapIfNeeded() async {
        guard !heatmapLoaded else { return }
        guard let userId = currentUserId else { return }

        isHeatmapLoading = true
        defer { isHeatmapLoading = false }

        do {
            let sessions = try await firestoreService.getRunSessions(userId: userId, limit: 20)
            let resolution = h3Service.defaultResolution
            var counts: [String: Int] = [:]
            for session in sessions {
                for point in session.route {
                    let index = point.coordinate.h3Index(resolution: resolution)
                    counts[index, default: 0] += 1
                }
            }
            heatmapCells = counts
            heatmapLoaded = true
        } catch {
            AppLogger.firebase.error("Failed to load heatmap: \(error.localizedDescription)")
        }
    }

    private func loadOwnerProfile(for userId: String) async {
        if let cached = ownerProfilesById[userId] {
            selectedOwnerProfile = cached
            return
        }

        do {
            if let user = try await firestoreService.getUser(id: userId) {
                ownerProfilesById[userId] = user
                if selectedTerritory?.ownerId == userId {
                    selectedOwnerProfile = user
                }
            } else if selectedTerritory?.ownerId == userId {
                selectedOwnerProfile = nil
            }
        } catch {
            AppLogger.firebase.error("Failed to load territory owner preview: \(error.localizedDescription)")
        }
    }
}

