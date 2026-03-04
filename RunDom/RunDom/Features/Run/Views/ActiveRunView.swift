import SwiftUI
import MapKit

struct ActiveRunView: View {
    @StateObject var viewModel: ActiveRunViewModel
    let onFinish: (RunSession) -> Void

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

            // Speed Indicator (top right)
            VStack {
                HStack {
                    Spacer()
                    SpeedIndicatorView(
                        currentSpeed: viewModel.currentSpeed,
                        mode: viewModel.mode,
                        isBoostActive: viewModel.isBoostActive
                    )
                }
                .padding(.top, 60)
                .padding(.trailing, 16)

                Spacer()
            }

            // Bottom stats + controls
            VStack {
                Spacer()

                // Stats overlay
                RunStatsOverlayView(
                    distance: viewModel.distanceKm,
                    elapsedTime: viewModel.formattedElapsedTime,
                    pace: viewModel.pace,
                    territories: viewModel.territoriesCaptured,
                    uniqueZones: viewModel.uniqueZones.count
                )
                .padding(.horizontal, AppConstants.UI.screenPadding)

                // Control button
                HStack(spacing: 24) {
                    // Pause button
                    Button {
                        viewModel.pauseRun()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }

                    // Stop button
                    Button {
                        let session = viewModel.stopRun()
                        onFinish(session)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(Color.red)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                }
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
        }
        .onAppear {
            viewModel.startRun()
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
        // Update route overlay
        guard routePoints.count >= 2 else { return }

        // Remove old overlays
        mapView.removeOverlays(mapView.overlays)

        // Draw route polyline
        let coordinates = routePoints.map(\.coordinate)
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
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
