import SwiftUI
import MapKit

struct ActiveRunView: View {
    @StateObject var viewModel: ActiveRunViewModel
    let onFinish: (RunSession) -> Void
    @State private var showCountdown = true
    @State private var hasStartedRun = false
    @State private var showTerritoryConquestAnimation = false
    @State private var pendingTerritoryConquestAnimations = 0
    @State private var territoryAnimationId = 0

    var body: some View {
        ZStack {
            // Map background
            RunMapView(routePoints: viewModel.routePoints, currentLocation: viewModel.routePoints.last?.coordinate)
                .ignoresSafeArea()

            // GPS Signal Warning
            if viewModel.gpsSignalLost {
                VStack {
                    gpsWarningBanner
                    Spacer()
                }
                .padding(.top, 60)
            }

            // Bottom stats + controls
            VStack {
                Spacer()

                // Stats overlay
                RunStatsOverlayView(
                    currentSpeed: viewModel.currentSpeed,
                    mode: viewModel.mode,
                    isBoostActive: viewModel.isBoostActive,
                    distance: viewModel.distanceKm,
                    elapsedTime: viewModel.formattedElapsedTime,
                    territories: viewModel.territoriesCaptured
                )
                .padding(.horizontal, AppConstants.UI.screenPadding)

                // Control button
                Button {
                    Haptics.impact(.medium)
                    viewModel.pauseRun()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(
                            Circle()
                                .fill(Color.orange)
                                .shadow(color: .black.opacity(0.26), radius: 14, y: 8)
                        )
                }
                .accessibilityLabel("run.pause".localized)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }

            // Pause overlay
            if viewModel.runState == .paused {
                PauseRunView(
                    elapsedTime: viewModel.formattedElapsedTime,
                    distance: viewModel.distanceKm,
                    onResume: { viewModel.resumeRun() },
                    onStop: {
                        let session = viewModel.stopRun()
                        onFinish(session)
                    }
                )
                .transition(.opacity)
            }

            if showCountdown {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                LottieView(
                    animationName: "run_countdown",
                    loopMode: .playOnce,
                    onCompletion: {
                        guard !hasStartedRun else { return }
                        hasStartedRun = true
                        showCountdown = false
                        viewModel.startRun()
                    }
                )
                    .frame(width: 260, height: 260)
            }

        }
        .overlay {
            if showTerritoryConquestAnimation {
                ZStack {
                    Color.black.opacity(0.22)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        LottieView(
                            animationName: "Unlocked",
                            loopMode: .playOnce,
                            contentMode: .scaleAspectFit,
                            animationSpeed: 1.0,
                            onCompletion: { finishTerritoryConquestAnimation() }
                        )
                        .id(territoryAnimationId)
                        .frame(width: 220, height: 220)

                        Text("run.territoryConquered".localized)
                            .font(.headline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .allowsHitTesting(false)
                .transition(.opacity)
                .task(id: territoryAnimationId) {
                    try? await Task.sleep(for: .seconds(4))
                    if !Task.isCancelled && showTerritoryConquestAnimation {
                        finishTerritoryConquestAnimation()
                    }
                }
            }
        }
        .onAppear {
            guard !hasStartedRun else { return }
            showCountdown = true
        }
        .onChange(of: viewModel.gpsSignalLost) { _, isLost in
            if isLost { Haptics.notification(.warning) }
        }
        .onChange(of: viewModel.territoriesCaptured) { oldValue, newValue in
            if newValue > oldValue { Haptics.notification(.success) }
        }
        .onChange(of: viewModel.territoryConquestAnimationTrigger) { oldValue, newValue in
            guard newValue > oldValue else { return }
            enqueueTerritoryConquestAnimation(count: newValue - oldValue)
        }
        .statusBarHidden(viewModel.runState == .running)
    }

    // MARK: - GPS Warning

    private var gpsWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(.white)
            Text("run.gpsLost".localized)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.9))
        .clipShape(Capsule())
    }

    private func enqueueTerritoryConquestAnimation(count: Int) {
        guard count > 0 else { return }

        if showTerritoryConquestAnimation {
            pendingTerritoryConquestAnimations += count
            return
        }

        territoryAnimationId += 1
        showTerritoryConquestAnimation = true
        if count > 1 {
            pendingTerritoryConquestAnimations += (count - 1)
        }
    }

    private func finishTerritoryConquestAnimation() {
        if pendingTerritoryConquestAnimations > 0 {
            pendingTerritoryConquestAnimations -= 1
            showTerritoryConquestAnimation = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                territoryAnimationId += 1
                showTerritoryConquestAnimation = true
            }
            return
        }

        showTerritoryConquestAnimation = false
    }
}

// MARK: - Run Map View (UIViewRepresentable)

struct RunMapView: UIViewRepresentable {
    let routePoints: [RoutePoint]
    let currentLocation: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.mapType = .standard
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        guard routePoints.count >= 2 else { return }

        let coordinator = context.coordinator
        let newCount = routePoints.count

        // Only redraw when a new point has been added (throttle to every 5 points)
        guard newCount != coordinator.lastRenderedPointCount,
              newCount % 5 == 0 || newCount - coordinator.lastRenderedPointCount >= 5 else {
            return
        }

        coordinator.lastRenderedPointCount = newCount

        mapView.removeOverlays(mapView.overlays)
        let coordinates = routePoints.map(\.coordinate)
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var lastRenderedPointCount = 0

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
