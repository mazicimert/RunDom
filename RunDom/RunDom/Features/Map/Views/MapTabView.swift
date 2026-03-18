import MapKit
import SwiftUI

struct MapTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: MapViewModel

    init(locationManager: LocationManager) {
        _viewModel = StateObject(wrappedValue: MapViewModel(locationManager: locationManager))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Map
            TerritoryMapView(
                region: $viewModel.region,
                territories: viewModel.shouldRenderOverlays ? viewModel.visibleTerritories : [],
                dropzones: [],
                onTerritoryTapped: { viewModel.selectTerritory($0) },
                onDropzoneTapped: nil
            )
            .ignoresSafeArea(edges: .top)

            // Overlays
            VStack {
                // Error Banner
                if let error = viewModel.errorMessage {
                    ErrorBannerView(
                        message: error,
                        onDismiss: { viewModel.dismissError() },
                        onRetry: {
                            Task { await viewModel.onAppear(currentUser: appState.currentUser) }
                        }
                    )
                    .padding(.top, 8)
                }

                Spacer()

                // Bottom Controls
                HStack {
                    // Territory Count Badge
                    territoryCountBadge

                    Spacer()

                    // Center on User Button
                    centerButton
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
        .sheet(item: $viewModel.selectedTerritory) { territory in
            TerritoryDetailSheet(
                territory: territory,
                currentUserId: appState.currentUser?.id
            )
        }
        .task {
            await viewModel.onAppear(currentUser: appState.currentUser)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: viewModel.territories) {
            if let userId = appState.currentUser?.id {
                viewModel.updateUserTerritoryCount(userId: userId)
            }
        }
    }

    // MARK: - Territory Count Badge

    private var territoryCountBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "hexagon.fill")
                .font(.subheadline)
            Text("\(viewModel.userTerritoryCount)")
                .font(.subheadline.bold().monospacedDigit())
        }
        .foregroundStyle(mapControlForegroundColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(mapControlBackgroundColor, in: Capsule())
        .overlay(Capsule().stroke(mapControlBorderColor, lineWidth: 1))
        .shadow(color: mapControlShadowColor, radius: 8, x: 0, y: 4)
        .accessibilityLabel(
            "accessibility.map.territoryCount".localized(with: viewModel.userTerritoryCount)
        )
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Center Button

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

struct TerritoryMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let territories: [Territory]
    let dropzones: [Dropzone]
    var onTerritoryTapped: ((Territory) -> Void)?
    var onDropzoneTapped: ((Dropzone) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        mapView.showsCompass = true
        mapView.isRotateEnabled = false
        mapView.mapType = .standard

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.territories = territories
        context.coordinator.dropzones = dropzones
        context.coordinator.onTerritoryTapped = onTerritoryTapped
        context.coordinator.onDropzoneTapped = onDropzoneTapped

        // Apply programmatic region changes
        let currentCenter = mapView.region.center
        let targetCenter = region.center
        let threshold = 0.0001  // ~11 meters
        if abs(currentCenter.latitude - targetCenter.latitude) > threshold
            || abs(currentCenter.longitude - targetCenter.longitude) > threshold
        {
            context.coordinator.isUpdatingRegion = true
            mapView.setRegion(region, animated: true)
            // Reset flag after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                context.coordinator.isUpdatingRegion = false
            }
        }

        updateOverlays(mapView)
        updateAnnotations(mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Update Overlays

    private func updateOverlays(_ mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)

        for territory in territories {
            guard let polygon = MKPolygon.fromH3Index(territory.h3Index) else { continue }
            polygon.title = territory.h3Index
            mapView.addOverlay(polygon)
        }
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
        var dropzones: [Dropzone] = []
        var onTerritoryTapped: ((Territory) -> Void)?
        var onDropzoneTapped: ((Dropzone) -> Void)?
        var isUpdatingRegion = false

        init(_ parent: TerritoryMapView) {
            self.parent = parent
        }

        // MARK: - Overlay Rendering

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon,
                let h3Index = polygon.title,
                let territory = territories.first(where: { $0.h3Index == h3Index })
            else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let uiColor = UIColor(Color(hex: territory.ownerColor) ?? .blue)
            return TerritoryOverlayRenderer(
                polygon: polygon,
                color: uiColor,
                isDecaying: territory.isDecaying
            )
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

        // MARK: - Tap Handling

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
            }
        }
    }
}
