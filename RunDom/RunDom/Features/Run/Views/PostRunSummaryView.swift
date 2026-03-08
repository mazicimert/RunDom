import SwiftUI
import MapKit

struct PostRunSummaryView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: PostRunViewModel
    let onDismiss: () -> Void

    init(session: RunSession, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: PostRunViewModel(session: session))
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Route Map
                    routeMapSection

                    // Trail Points
                    trailSection

                    // Stats Grid
                    statsGrid

                    // Multiplier Breakdown
                    if let result = viewModel.trailResult {
                        multiplierBreakdown(result: result)
                    }

                    // Error
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, AppConstants.UI.screenPadding)
                    }

                    // Save indicator
                    if viewModel.isSaving {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("run.saving".localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("run.summary".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("run.done".localized) {
                        onDismiss()
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .task {
                if let user = appState.currentUser {
                    await viewModel.processRun(user: user)
                }
            }
            .onChange(of: viewModel.isSaved) { _, saved in
                if saved { Haptics.notification(.success) }
            }
            .onChange(of: viewModel.errorMessage) { _, message in
                if message != nil { Haptics.notification(.error) }
            }
        }
    }

    // MARK: - Route Map

    private var routeMapSection: some View {
        Group {
            if viewModel.session.route.count >= 2 {
                PostRunMapView(routePoints: viewModel.session.route)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius))
                    .padding(.horizontal, AppConstants.UI.screenPadding)
            }
        }
    }

    // MARK: - Trail Points

    private var trailSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.trailText)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("\(viewModel.trailText) \("run.trailEarned".localized)")

            Text("run.trailEarned".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            // Mode badge
            Text(viewModel.modeText)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(viewModel.session.mode == .boost ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                )
                .foregroundStyle(viewModel.session.mode == .boost ? .orange : .blue)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCardView(
                icon: "ruler",
                value: String(format: "%.2f km", viewModel.distanceKm),
                label: "run.distance".localized
            )

            StatCardView(
                icon: "clock",
                value: viewModel.durationText,
                label: "run.duration".localized
            )

            StatCardView(
                icon: "speedometer",
                value: viewModel.avgSpeedText,
                label: "run.avgSpeed".localized
            )

            StatCardView(
                icon: "map",
                value: "\(viewModel.session.territoriesCaptured)",
                label: "run.territories".localized
            )
        }
        .padding(.horizontal, AppConstants.UI.screenPadding)
    }

    // MARK: - Multiplier Breakdown

    @ViewBuilder
    private func multiplierBreakdown(result: TrailCalculator.TrailResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("run.breakdown".localized)
                .font(.headline)

            multiplierRow(label: "run.basePoints".localized, value: String(format: "%.0f", result.basePoints))
            multiplierRow(label: "run.speedMultiplier".localized, value: String(format: "x%.2f", result.speedMultiplier))
            multiplierRow(label: "run.durationMultiplier".localized, value: String(format: "x%.2f", result.durationMultiplier))
            multiplierRow(label: "run.zoneMultiplier".localized, value: String(format: "x%.2f", result.zoneMultiplier))
            multiplierRow(label: "run.streakMultiplier".localized, value: String(format: "x%.2f", result.streakMultiplier))

            if result.modeMultiplier > 1.0 {
                multiplierRow(label: "run.boostMultiplier".localized, value: String(format: "x%.1f", result.modeMultiplier))
            }

            if result.antiFarmMultiplier < 1.0 {
                multiplierRow(label: "run.antiFarmMultiplier".localized, value: String(format: "x%.2f", result.antiFarmMultiplier), isNegative: true)
            }

            if result.wasCapped {
                Text("run.capped".localized)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if result.wasDailyCapped {
                Text("run.dailyCapped".localized)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(AppConstants.UI.cardPadding)
        .cardStyle()
        .padding(.horizontal, AppConstants.UI.screenPadding)
    }

    @ViewBuilder
    private func multiplierRow(label: String, value: String, isNegative: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(isNegative ? .red : .primary)
        }
    }
}

// MARK: - Post Run Map View

struct PostRunMapView: UIViewRepresentable {
    let routePoints: [RoutePoint]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = false
        mapView.mapType = .standard
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard routePoints.count >= 2 else { return }

        let coordinates = routePoints.map(\.coordinate)
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        // Add start/end annotations
        let startAnnotation = MKPointAnnotation()
        startAnnotation.coordinate = coordinates.first!
        startAnnotation.title = "run.startPoint".localized

        let endAnnotation = MKPointAnnotation()
        endAnnotation.coordinate = coordinates.last!
        endAnnotation.title = "run.endPoint".localized

        mapView.addAnnotations([startAnnotation, endAnnotation])

        // Fit map to route
        let rect = polyline.boundingMapRect
        let insets = UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)
        mapView.setVisibleMapRect(rect, edgePadding: insets, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
