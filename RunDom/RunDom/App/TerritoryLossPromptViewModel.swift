import Foundation

@MainActor
final class TerritoryLossPromptViewModel: ObservableObject {
    @Published private(set) var events: [TerritoryLossEvent] = []
    @Published private(set) var selectedIndex: Int = 0
    @Published private(set) var locationLabels: [String: String] = [:]
    @Published private(set) var loadingLocationEventIds = Set<String>()

    private let territoryLossService: TerritoryLossService
    private let geocodingService: GeocodingService
    private let h3Service: H3GridService
    private var activeUserId: String?

    init(
        territoryLossService: TerritoryLossService = TerritoryLossService(),
        geocodingService: GeocodingService = .shared,
        h3Service: H3GridService = .shared
    ) {
        self.territoryLossService = territoryLossService
        self.geocodingService = geocodingService
        self.h3Service = h3Service
    }

    var selectedEvent: TerritoryLossEvent? {
        guard events.indices.contains(selectedIndex) else { return nil }
        return events[selectedIndex]
    }

    var hasEvents: Bool {
        !events.isEmpty
    }

    var canGoNext: Bool {
        selectedIndex < events.count - 1
    }

    var counterText: String {
        guard hasEvents else { return "" }
        return "\(selectedIndex + 1)/\(events.count)"
    }

    var bodyText: String {
        if events.count <= 1 {
            return "territoryLoss.prompt.body.single".localized
        }
        return "territoryLoss.prompt.body.multiple".localized(with: events.count)
    }

    var locationText: String {
        guard let event = selectedEvent else { return "" }
        if let label = locationLabels[event.id] {
            return label
        }
        if loadingLocationEventIds.contains(event.id) {
            return "territoryLoss.prompt.locationLoading".localized
        }
        return "territoryLoss.prompt.locationFallback".localized
    }

    var capturedByText: String? {
        guard let name = selectedEvent?.capturerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }
        return "territoryLoss.prompt.capturedBy".localized(with: name)
    }

    var capturedAtText: String? {
        selectedEvent?.capturedAt.relativeFormatted()
    }

    func loadUnreadEvents(userId: String, initialLossEventId: String? = nil) async -> Bool {
        activeUserId = userId

        do {
            var unreadEvents = try await territoryLossService.loadUnreadLossEvents(userId: userId)
            guard !unreadEvents.isEmpty else {
                clear()
                return false
            }

            if let initialLossEventId,
               let preferredIndex = unreadEvents.firstIndex(where: { $0.id == initialLossEventId }) {
                let preferredEvent = unreadEvents.remove(at: preferredIndex)
                unreadEvents.insert(preferredEvent, at: 0)
            }

            events = unreadEvents
            selectedIndex = 0
            locationLabels = Dictionary(
                uniqueKeysWithValues: locationLabels.filter { key, _ in
                    unreadEvents.contains(where: { $0.id == key })
                }
            )
            loadingLocationEventIds.removeAll()

            await resolveLocationForSelectedEventIfNeeded()
            return true
        } catch {
            AppLogger.firebase.error("Failed to load unread territory losses: \(error.localizedDescription)")
            return false
        }
    }

    func moveToNextEvent() {
        guard canGoNext else { return }
        selectedIndex += 1
        Task { await resolveLocationForSelectedEventIfNeeded() }
    }

    func markBatchSeenAndClear() async {
        defer { clear() }

        guard let activeUserId, !events.isEmpty else { return }

        do {
            try await territoryLossService.markLossEventsSeen(
                userId: activeUserId,
                eventIds: events.map(\.id)
            )
        } catch {
            AppLogger.firebase.error("Failed to mark territory losses seen: \(error.localizedDescription)")
        }
    }

    func clear() {
        events = []
        selectedIndex = 0
        locationLabels.removeAll()
        loadingLocationEventIds.removeAll()
    }

    private func resolveLocationForSelectedEventIfNeeded() async {
        guard let event = selectedEvent,
              locationLabels[event.id] == nil,
              !loadingLocationEventIds.contains(event.id) else {
            return
        }

        guard let coordinate = h3Service.coordinate(fromIndex: event.h3Index) else {
            locationLabels[event.id] = "territoryLoss.prompt.locationFallback".localized
            return
        }

        loadingLocationEventIds.insert(event.id)
        defer { loadingLocationEventIds.remove(event.id) }

        let fullLocality = await geocodingService.fullLocalityName(for: coordinate)
        let neighborhood = fullLocality == nil
            ? await geocodingService.neighborhoodName(for: coordinate)
            : nil
        let label = fullLocality
            ?? neighborhood
            ?? "territoryLoss.prompt.locationFallback".localized

        locationLabels[event.id] = label
    }
}
