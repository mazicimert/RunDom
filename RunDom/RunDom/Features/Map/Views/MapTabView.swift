import Combine
import MapKit
import SwiftUI

struct MapTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: MapViewModel

    init(locationManager: LocationManager) {
        _viewModel = StateObject(wrappedValue: MapViewModel(locationManager: locationManager))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Map
            TerritoryMapView(
                region: $viewModel.region,
                territories: viewModel.isHeatmapEnabled
                    ? []
                    : (viewModel.shouldRenderOverlays ? viewModel.visibleTerritories : []),
                selectedTerritoryId: viewModel.selectedTerritory?.h3Index,
                currentUserId: appState.currentUser?.id,
                dropzones: [],
                mapType: viewModel.mapStyle.mkMapType,
                heatmapCells: (viewModel.isHeatmapEnabled && viewModel.shouldRenderOverlays)
                    ? viewModel.visibleHeatmapCells
                    : [:],
                userColor: appState.currentUser?.color ?? "#4ECDC4",
                inspectedH3Index: viewModel.inspectedCell?.h3Index,
                onTerritoryTapped: {
                    viewModel.dismissInspection()
                    viewModel.selectTerritory($0)
                },
                onMapBackgroundTapped: {
                    viewModel.dismissInspection()
                    viewModel.clearSelection()
                },
                onDropzoneTapped: nil,
                onLongPress: { coord in
                    Haptics.impact(.medium)
                    viewModel.inspectCell(at: coord, currentUser: appState.currentUser)
                }
            )
            .ignoresSafeArea(edges: .top)

            // Overlays
            VStack(spacing: 12) {
                headerOverlay

                Spacer()

                // Bottom Controls
                HStack(alignment: .bottom) {
                    // Territory Count Badge
                    territoryCountBadge

                    Spacer()

                    VStack(spacing: 12) {
                        heatmapToggleButton
                        zoomInButton
                        zoomOutButton
                        centerButton
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.bottom, 16)
            }

            // Loading
            if viewModel.isLoading {
                LoadingView(message: "common.loading".localized)
            }
        }
        .navigationTitle("tab.map".localized)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let inspection = viewModel.inspectedCell {
                CellInspectorBar(
                    inspection: inspection,
                    ownerDisplayName: viewModel.inspectedOwnerDisplayName,
                    onDismiss: { viewModel.dismissInspection() },
                    onOpenDetails: {
                        viewModel.openInspectedTerritoryDetails()
                        viewModel.dismissInspection()
                    }
                )
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.inspectedCell?.h3Index)
        .sheet(item: $viewModel.presentedTerritory) { territory in
            TerritoryDetailSheet(
                territory: territory,
                currentUserId: appState.currentUser?.id
            )
        }
        .task(id: appState.currentUser?.id) {
            await viewModel.onAppear(currentUser: appState.currentUser)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: viewModel.territories) {
            if let userId = appState.currentUser?.id {
                viewModel.updateUserTerritoryCount(userId: userId)
            }
            viewModel.refreshSelection()
        }
        .onChange(of: appState.currentUser?.totalRuns) {
            viewModel.invalidateHeatmapCache()
        }
        .onChange(of: viewModel.region.center.latitude) {
            if viewModel.inspectedCell != nil {
                viewModel.dismissInspection()
            }
        }
        .onChange(of: viewModel.region.center.longitude) {
            if viewModel.inspectedCell != nil {
                viewModel.dismissInspection()
            }
        }
        .onReceive(router.$mapFocusRequest.compactMap { $0 }) { request in
            viewModel.focusTerritoryLoss(h3Index: request.h3Index)
            router.clearMapFocusRequest()
        }
    }

    private var headerOverlay: some View {
        VStack(spacing: 12) {
            if let error = viewModel.errorMessage {
                ErrorBannerView(
                    message: error,
                    onDismiss: { viewModel.dismissError() },
                    onRetry: {
                        Task { await viewModel.onAppear(currentUser: appState.currentUser) }
                    }
                )
            }

            territoryFilterBar

            if let selectedTerritory = viewModel.selectedTerritory {
                selectedTerritoryCallout(territory: selectedTerritory)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, AppConstants.UI.screenPadding)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedTerritory?.h3Index)
        .animation(.easeInOut(duration: 0.2), value: viewModel.territoryFilter)
    }

    private var territoryFilterBar: some View {
        HStack(spacing: 8) {
            ForEach(TerritoryFilter.allCases) { filter in
                let isSelected = viewModel.territoryFilter == filter

                Button {
                    Haptics.selection()
                    viewModel.setTerritoryFilter(filter)
                } label: {
                    Text(filter.titleKey.localized)
                        .font(.caption.bold())
                        .foregroundStyle(isSelected ? .white : mapControlForegroundColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor : mapControlBackgroundColor)
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.accentColor : mapControlBorderColor, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            mapStyleMenu
        }
    }

    private var mapStyleMenu: some View {
        Menu {
            Picker(
                "map.style.title".localized,
                selection: Binding(
                    get: { viewModel.mapStyle },
                    set: { newValue in
                        Haptics.selection()
                        viewModel.mapStyle = newValue
                    }
                )
            ) {
                ForEach(MapStyleOption.allCases) { option in
                    Text(option.titleKey.localized).tag(option)
                }
            }
        } label: {
            Image(systemName: "map")
                .font(.caption.bold())
                .foregroundStyle(mapControlForegroundColor)
                .frame(width: 36, height: 36)
                .background(mapControlBackgroundColor, in: Circle())
                .overlay(Circle().stroke(mapControlBorderColor, lineWidth: 1))
                .shadow(color: mapControlShadowColor, radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel("accessibility.map.style".localized)
    }

    private func selectedTerritoryCallout(territory: Territory) -> some View {
        HStack(spacing: 12) {
            AvatarView(
                photoURL: viewModel.selectedTerritoryOwnerPhotoURL,
                userColor: territory.ownerColor,
                size: 52
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(viewModel.selectedTerritoryOwnerName)
                        .font(.headline)
                        .lineLimit(1)

                    Text(
                        viewModel.selectedTerritoryIsCurrentUserOwned
                            ? "map.badge.mine".localized
                            : "map.badge.rival".localized
                    )
                    .font(.caption2.bold())
                    .foregroundStyle(viewModel.selectedTerritoryIsCurrentUserOwned ? Color.boostGreen : Color.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (viewModel.selectedTerritoryIsCurrentUserOwned ? Color.boostGreen : Color.orange)
                            .opacity(0.14),
                        in: Capsule()
                    )
                }

                Text("map.territoriesOwned".localized(with: viewModel.selectedTerritoryOwnedCount))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(
                    "map.ownerCalloutMeta".localized(
                        with: viewModel.selectedTerritoryLastActiveText,
                        viewModel.selectedTerritoryOwnerNeighborhood ?? "map.ownerCalloutNoArea".localized
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                Haptics.impact(.light)
                viewModel.presentSelectedTerritoryDetails()
            } label: {
                Text("map.viewDetails".localized)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
        .contentShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous))
        .onTapGesture {
            viewModel.presentSelectedTerritoryDetails()
        }
    }

    // MARK: - Territory Count Badge

    private var territoryCountBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "hexagon.fill")
                .font(.subheadline)

            if viewModel.hasLoadedInitialTerritories {
                Text("\(viewModel.userTerritoryCount)")
                    .font(.subheadline.bold().monospacedDigit())
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(mapControlForegroundColor.opacity(0.18))
                    .frame(width: 18, height: 14)
            }
        }
        .foregroundStyle(mapControlForegroundColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(mapControlBackgroundColor, in: Capsule())
        .overlay(Capsule().stroke(mapControlBorderColor, lineWidth: 1))
        .shadow(color: mapControlShadowColor, radius: 8, x: 0, y: 4)
        .accessibilityLabel(
            viewModel.hasLoadedInitialTerritories
                ? "accessibility.map.territoryCount".localized(with: viewModel.userTerritoryCount)
                : "common.loading".localized
        )
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Zoom & Center Buttons

    private var heatmapToggleButton: some View {
        Button {
            Haptics.selection()
            viewModel.isHeatmapEnabled.toggle()
        } label: {
            ZStack {
                Image(systemName: viewModel.isHeatmapEnabled ? "flame.fill" : "flame")
                    .font(.body.bold())
                    .foregroundStyle(viewModel.isHeatmapEnabled ? Color.boostGreen : mapControlForegroundColor)
                    .frame(width: 44, height: 44)
                    .background(mapControlBackgroundColor, in: Circle())
                    .overlay(Circle().stroke(
                        viewModel.isHeatmapEnabled ? Color.boostGreen : mapControlBorderColor,
                        lineWidth: 1
                    ))
                    .shadow(color: mapControlShadowColor, radius: 8, x: 0, y: 4)

                if viewModel.isHeatmapLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                }
            }
        }
        .accessibilityLabel("accessibility.map.heatmap".localized)
    }

    private var zoomInButton: some View {
        Button {
            Haptics.selection()
            viewModel.zoomIn()
        } label: {
            Image(systemName: "plus.magnifyingglass")
                .font(.body.bold())
                .foregroundStyle(mapControlForegroundColor)
                .frame(width: 44, height: 44)
                .background(mapControlBackgroundColor, in: Circle())
                .overlay(Circle().stroke(mapControlBorderColor, lineWidth: 1))
                .shadow(color: mapControlShadowColor, radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel("accessibility.map.zoomIn".localized)
    }

    private var zoomOutButton: some View {
        Button {
            Haptics.selection()
            viewModel.zoomOut()
        } label: {
            Image(systemName: "minus.magnifyingglass")
                .font(.body.bold())
                .foregroundStyle(mapControlForegroundColor)
                .frame(width: 44, height: 44)
                .background(mapControlBackgroundColor, in: Circle())
                .overlay(Circle().stroke(mapControlBorderColor, lineWidth: 1))
                .shadow(color: mapControlShadowColor, radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel("accessibility.map.zoomOut".localized)
    }

    private var centerButton: some View {
        Button {
            Haptics.selection()
            viewModel.centerOnUser()
        } label: {
            Image(systemName: "location.fill")
                .font(.body.bold())
                .foregroundStyle(mapControlForegroundColor)
                .frame(width: 44, height: 44)
                .background(mapControlBackgroundColor, in: Circle())
                .overlay(Circle().stroke(mapControlBorderColor, lineWidth: 1))
                .shadow(color: mapControlShadowColor, radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel("accessibility.map.centerOnUser".localized)
    }

    // MARK: - Map Controls Style

    private var mapControlBackgroundColor: Color {
        colorScheme == .light
            ? Color(uiColor: .systemBackground).opacity(0.96)
            : Color(uiColor: .secondarySystemBackground).opacity(0.88)
    }

    private var mapControlForegroundColor: Color {
        Color(uiColor: .label)
    }

    private var mapControlBorderColor: Color {
        colorScheme == .light ? .black.opacity(0.12) : .white.opacity(0.2)
    }

    private var mapControlShadowColor: Color {
        colorScheme == .light ? .black.opacity(0.18) : .black.opacity(0.34)
    }
}

// MARK: - UIKit Map View (UIViewRepresentable)

final class HeatmapPolygon: MKPolygon {}
final class InspectionPolygon: MKPolygon {}

struct TerritoryMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let territories: [Territory]
    let selectedTerritoryId: String?
    let currentUserId: String?
    let dropzones: [Dropzone]
    var mapType: MKMapType = .standard
    var heatmapCells: [String: Int] = [:]
    var userColor: String = "#4ECDC4"
    var inspectedH3Index: String?
    var onTerritoryTapped: ((Territory) -> Void)?
    var onMapBackgroundTapped: (() -> Void)?
    var onDropzoneTapped: ((Dropzone) -> Void)?
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        mapView.showsCompass = true
        mapView.isRotateEnabled = false
        mapView.mapType = mapType

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.territories = territories
        context.coordinator.selectedTerritoryId = selectedTerritoryId
        context.coordinator.currentUserId = currentUserId
        context.coordinator.dropzones = dropzones
        context.coordinator.heatmapCells = heatmapCells
        context.coordinator.userColor = userColor
        context.coordinator.inspectedH3Index = inspectedH3Index
        context.coordinator.onTerritoryTapped = onTerritoryTapped
        context.coordinator.onMapBackgroundTapped = onMapBackgroundTapped
        context.coordinator.onDropzoneTapped = onDropzoneTapped
        context.coordinator.onLongPress = onLongPress

        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        // Apply programmatic region changes
        let currentCenter = mapView.region.center
        let targetCenter = region.center
        let currentSpan = mapView.region.span
        let targetSpan = region.span
        let centerThreshold = 0.0001  // ~11 meters
        let centerChanged = abs(currentCenter.latitude - targetCenter.latitude) > centerThreshold
            || abs(currentCenter.longitude - targetCenter.longitude) > centerThreshold
        // Span delta threshold is relative so it triggers at any zoom level.
        let spanChanged =
            abs(currentSpan.latitudeDelta - targetSpan.latitudeDelta)
                > currentSpan.latitudeDelta * 0.05
            || abs(currentSpan.longitudeDelta - targetSpan.longitudeDelta)
                > currentSpan.longitudeDelta * 0.05
        if centerChanged || spanChanged {
            context.coordinator.isUpdatingRegion = true
            mapView.setRegion(region, animated: true)
            // Reset flag after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                context.coordinator.isUpdatingRegion = false
            }
        }

        updateOverlays(mapView)
        updateHeatmapOverlays(mapView)
        updateInspectionOverlay(mapView)
        context.coordinator.refreshOverlayStylesIfNeeded(on: mapView)
        updateAnnotations(mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Update Overlays

    private func updateOverlays(_ mapView: MKMapView) {
        let existingOverlays = mapView.overlays.compactMap { overlay -> (String, MKPolygon)? in
            guard let polygon = overlay as? MKPolygon,
                  !(polygon is HeatmapPolygon),
                  !(polygon is InspectionPolygon),
                  let h3Index = polygon.title else {
                return nil
            }
            return (h3Index, polygon)
        }
        let existingById = Dictionary(uniqueKeysWithValues: existingOverlays)

        let targetTerritories = Dictionary(uniqueKeysWithValues: territories.map { ($0.h3Index, $0) })
        let targetIds = Set(targetTerritories.keys)
        let existingIds = Set(existingById.keys)

        let idsToRemove = existingIds.subtracting(targetIds)
        if !idsToRemove.isEmpty {
            let overlaysToRemove = idsToRemove.compactMap { existingById[$0] }
            mapView.removeOverlays(overlaysToRemove)
        }

        let idsToAdd = targetIds.subtracting(existingIds)
        if !idsToAdd.isEmpty {
            let overlaysToAdd = idsToAdd.compactMap { h3Index -> MKPolygon? in
                guard let polygon = MKPolygon.fromH3Index(h3Index) else { return nil }
                polygon.title = h3Index
                return polygon
            }
            mapView.addOverlays(overlaysToAdd)
        }
    }

    private func updateHeatmapOverlays(_ mapView: MKMapView) {
        let existingHeatmap = mapView.overlays.compactMap { overlay -> (String, HeatmapPolygon)? in
            guard let polygon = overlay as? HeatmapPolygon,
                  let h3Index = polygon.title else {
                return nil
            }
            return (h3Index, polygon)
        }
        let existingById = Dictionary(uniqueKeysWithValues: existingHeatmap)

        let targetIds = Set(heatmapCells.keys)
        let existingIds = Set(existingById.keys)

        let idsToRemove = existingIds.subtracting(targetIds)
        if !idsToRemove.isEmpty {
            let overlaysToRemove = idsToRemove.compactMap { existingById[$0] }
            mapView.removeOverlays(overlaysToRemove)
        }

        let idsToAdd = targetIds.subtracting(existingIds)
        if !idsToAdd.isEmpty {
            let overlaysToAdd = idsToAdd.compactMap { h3Index -> HeatmapPolygon? in
                guard let coordinate = H3GridService.shared.coordinate(fromIndex: h3Index) else { return nil }
                let resolution = H3GridService.shared.resolution(fromIndex: h3Index)
                let boundary = coordinate.h3HexBoundary(resolution: resolution)
                let polygon = HeatmapPolygon(coordinates: boundary, count: boundary.count)
                polygon.title = h3Index
                return polygon
            }
            mapView.addOverlays(overlaysToAdd)
        }
    }

    private func updateInspectionOverlay(_ mapView: MKMapView) {
        let existing = mapView.overlays.compactMap { $0 as? InspectionPolygon }

        guard let targetIndex = inspectedH3Index else {
            if !existing.isEmpty {
                mapView.removeOverlays(existing)
            }
            return
        }

        if existing.count == 1, existing.first?.title == targetIndex {
            return
        }

        if !existing.isEmpty {
            mapView.removeOverlays(existing)
        }

        guard let centerCoord = H3GridService.shared.coordinate(fromIndex: targetIndex) else { return }
        let resolution = H3GridService.shared.resolution(fromIndex: targetIndex)
        let boundary = centerCoord.h3HexBoundary(resolution: resolution)
        let polygon = InspectionPolygon(coordinates: boundary, count: boundary.count)
        polygon.title = targetIndex
        mapView.addOverlay(polygon, level: .aboveLabels)
    }

    // MARK: - Update Annotations

    private func updateAnnotations(_ mapView: MKMapView) {
        let existingAnnotations = mapView.annotations.compactMap { $0 as? DropzoneAnnotation }
        mapView.removeAnnotations(existingAnnotations)

        let annotations =
            dropzones
            .filter { $0.isActive || $0.isHintVisible }
            .map { DropzoneAnnotation(dropzone: $0) }
        mapView.addAnnotations(annotations)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let parent: TerritoryMapView
        var territories: [Territory] = []
        var selectedTerritoryId: String?
        var currentUserId: String?
        var dropzones: [Dropzone] = []
        var heatmapCells: [String: Int] = [:]
        var userColor: String = "#4ECDC4"
        var inspectedH3Index: String?
        var onTerritoryTapped: ((Territory) -> Void)?
        var onMapBackgroundTapped: (() -> Void)?
        var onDropzoneTapped: ((Dropzone) -> Void)?
        var onLongPress: ((CLLocationCoordinate2D) -> Void)?
        var isUpdatingRegion = false
        private var overlayStyleCache: [String: OverlayStyle] = [:]

        init(_ parent: TerritoryMapView) {
            self.parent = parent
        }

        // MARK: - Overlay Rendering

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let inspectionPolygon = overlay as? InspectionPolygon {
                let renderer = MKPolygonRenderer(polygon: inspectionPolygon)
                renderer.fillColor = UIColor.white.withAlphaComponent(0.08)
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.95)
                renderer.lineWidth = 3.5
                renderer.lineJoin = .round
                renderer.lineCap = .round
                return renderer
            }

            if let heatmapPolygon = overlay as? HeatmapPolygon,
               let h3Index = heatmapPolygon.title,
               let count = heatmapCells[h3Index] {
                let base = UIColor(Color(hex: userColor) ?? .blue)
                let normalized = min(Double(count), 10.0) / 10.0
                let alpha = 0.10 + normalized * (0.75 - 0.10)
                let renderer = MKPolygonRenderer(polygon: heatmapPolygon)
                renderer.fillColor = base.withAlphaComponent(CGFloat(alpha))
                renderer.strokeColor = .clear
                renderer.lineWidth = 0
                return renderer
            }

            guard let polygon = overlay as? MKPolygon,
                let h3Index = polygon.title,
                let territory = territories.first(where: { $0.h3Index == h3Index })
            else {
                return MKOverlayRenderer(overlay: overlay)
            }

            overlayStyleCache[h3Index] = OverlayStyle(
                ownerColor: territory.ownerColor,
                isDecaying: territory.isDecaying,
                isSelected: h3Index == selectedTerritoryId,
                isOwnedByCurrentUser: territory.ownerId == currentUserId
            )

            let uiColor = UIColor(Color(hex: territory.ownerColor) ?? .blue)
            let renderer = TerritoryOverlayRenderer(
                polygon: polygon,
                color: uiColor,
                isDecaying: territory.isDecaying
            )
            renderer.applyStyle(
                isSelected: h3Index == selectedTerritoryId,
                isOwnedByCurrentUser: territory.ownerId == currentUserId,
                isDimmed: selectedTerritoryId != nil && h3Index != selectedTerritoryId
            )
            return renderer
        }

        // MARK: - Annotation Views

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let dropzoneAnnotation = annotation as? DropzoneAnnotation else { return nil }

            let identifier = "DropzoneAnnotation"
            let annotationView =
                mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            annotationView.annotation = annotation
            annotationView.canShowCallout = false

            let hostingController = UIHostingController(
                rootView: DropzoneAnnotationView(dropzone: dropzoneAnnotation.dropzone)
            )
            hostingController.view.backgroundColor = .clear
            hostingController.view.frame = CGRect(x: 0, y: 0, width: 60, height: 70)

            annotationView.subviews.forEach { $0.removeFromSuperview() }
            annotationView.addSubview(hostingController.view)
            annotationView.frame = hostingController.view.frame
            annotationView.centerOffset = CGPoint(x: 0, y: -35)

            return annotationView
        }

        // MARK: - Region Change

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard !isUpdatingRegion else { return }
            parent.region = mapView.region
        }

        func refreshOverlayStylesIfNeeded(on mapView: MKMapView) {
            for overlay in mapView.overlays {
                guard let polygon = overlay as? MKPolygon,
                      !(polygon is HeatmapPolygon),
                      !(polygon is InspectionPolygon),
                      let h3Index = polygon.title,
                      let territory = territories.first(where: { $0.h3Index == h3Index }),
                      let renderer = mapView.renderer(for: polygon) as? TerritoryOverlayRenderer else {
                    continue
                }

                let newStyle = OverlayStyle(
                    ownerColor: territory.ownerColor,
                    isDecaying: territory.isDecaying,
                    isSelected: h3Index == selectedTerritoryId,
                    isOwnedByCurrentUser: territory.ownerId == currentUserId
                )

                guard overlayStyleCache[h3Index] != newStyle else { continue }

                overlayStyleCache[h3Index] = newStyle
                renderer.applyStyle(
                    isSelected: newStyle.isSelected,
                    isOwnedByCurrentUser: newStyle.isOwnedByCurrentUser,
                    isDimmed: selectedTerritoryId != nil && !newStyle.isSelected
                )
                renderer.setNeedsDisplay()
            }

            let liveIds = Set(territories.map(\.h3Index))
            overlayStyleCache = overlayStyleCache.filter { liveIds.contains($0.key) }
        }

        // MARK: - Tap Handling

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onLongPress?(coordinate)
        }

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // Check dropzone annotations first
            for annotation in mapView.annotations {
                guard let dropzoneAnnotation = annotation as? DropzoneAnnotation else { continue }
                let annotationPoint = mapView.convert(
                    dropzoneAnnotation.coordinate, toPointTo: mapView)
                let distance = hypot(point.x - annotationPoint.x, point.y - annotationPoint.y)
                if distance < 44 {
                    onDropzoneTapped?(dropzoneAnnotation.dropzone)
                    return
                }
            }

            // Check territory overlays
            let tappedIndex = coordinate.h3Index(resolution: AppConstants.Location.h3Resolution)
            if let territory = territories.first(where: { $0.h3Index == tappedIndex }) {
                onTerritoryTapped?(territory)
            } else {
                onMapBackgroundTapped?()
            }
        }

        private struct OverlayStyle: Equatable {
            let ownerColor: String
            let isDecaying: Bool
            let isSelected: Bool
            let isOwnedByCurrentUser: Bool
        }
    }
}
