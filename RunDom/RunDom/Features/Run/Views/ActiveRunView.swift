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
    @State private var statsDetent: PresentationDetent = RunStatsOverlayView.compactDetent
    @State private var showStatsSheet = true
    @State private var showRivalTerritoryBanner = false
    @State private var rivalTerritoryBannerTask: Task<Void, Never>?
    @State private var isFollowingUser = true
    @State private var recenterTrigger = 0
    @State private var isPlayingIntro = true
    @State private var introTimeoutTask: Task<Void, Never>?

    private static let introTimeoutSeconds: TimeInterval = 5.0

    var body: some View {
        ZStack {
            // Map background
            RunMapView(
                routePoints: viewModel.routePoints,
                currentLocation: viewModel.routePoints.last?.coordinate,
                rivalTerritories: viewModel.nearbyRivalTerritories,
                currentUserId: viewModel.userId,
                showsRivalOverlay: viewModel.isRivalOverlayEnabled,
                isFollowingUser: $isFollowingUser,
                recenterTrigger: recenterTrigger,
                onIntroComplete: { finishIntro() }
            )
                .ignoresSafeArea()

            if viewModel.gpsSignalLost || showRivalTerritoryBanner {
                VStack {
                    topStatusStack
                    Spacer()
                }
                .padding(.top, 60)
            }

            if showCountdown && !isPlayingIntro {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)

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
                    .transition(.opacity)
            }

        }
        .animation(.easeInOut(duration: 0.3), value: isPlayingIntro)
        .overlay(alignment: .topTrailing) {
            if !showCountdown && !isPlayingIntro {
                VStack(spacing: 12) {
                    rivalOverlayToggle

                    if !isFollowingUser {
                        recenterButton
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFollowingUser)
                .padding(.top, 60)
                .padding(.trailing, AppConstants.UI.screenPadding)
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
        .sheet(isPresented: $showStatsSheet) {
            RunStatsOverlayView(
                currentSpeed: viewModel.currentSpeed,
                avgSpeed: viewModel.avgSpeed,
                maxSpeed: viewModel.maxSpeed,
                pace: viewModel.pace,
                mode: viewModel.mode,
                isBoostActive: viewModel.isBoostActive,
                distance: viewModel.distanceKm,
                elapsedTime: viewModel.formattedElapsedTime,
                territories: viewModel.territoriesCaptured,
                uniqueZones: viewModel.uniqueZones.count,
                runState: viewModel.runState,
                gpsSignalLost: viewModel.gpsSignalLost,
                onPause: {
                    Haptics.impact(.medium)
                    viewModel.pauseRun()
                },
                onResume: {
                    Haptics.impact(.light)
                    viewModel.resumeRun()
                },
                onStop: {
                    let session = viewModel.stopRun()
                    onFinish(session)
                },
                selectedDetent: $statsDetent
            )
            .presentationDetents(
                [RunStatsOverlayView.compactDetent, RunStatsOverlayView.expandedDetent],
                selection: $statsDetent
            )
            .presentationBackgroundInteraction(.enabled(upThrough: RunStatsOverlayView.compactDetent))
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
            .interactiveDismissDisabled()
        }
        .onAppear {
            guard !hasStartedRun else { return }
            showCountdown = true
            startIntroTimeoutIfNeeded()
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
        .onChange(of: viewModel.rivalTerritoryEntryTrigger) { oldValue, newValue in
            guard newValue > oldValue else { return }
            presentRivalTerritoryBanner()
        }
        .onDisappear {
            rivalTerritoryBannerTask?.cancel()
            introTimeoutTask?.cancel()
        }
        .statusBarHidden(viewModel.runState == .running)
    }

    // MARK: - Top Status

    private var topStatusStack: some View {
        VStack(spacing: 10) {
            if viewModel.gpsSignalLost {
                gpsWarningBanner
            }

            if showRivalTerritoryBanner {
                rivalTerritoryBanner
            }
        }
    }

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

    private var rivalTerritoryBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(.white)
            Text("run.rivalOverlay.entered".localized)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.9))
        .clipShape(Capsule())
    }

    private var recenterButton: some View {
        Button {
            Haptics.selection()
            recenterTrigger &+= 1
        } label: {
            Image(systemName: "location.north.line.fill")
                .font(.body.bold())
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("accessibility.run.recenter".localized)
    }

    private var rivalOverlayToggle: some View {
        Button {
            Haptics.selection()
            viewModel.toggleRivalOverlay()
        } label: {
            Image(systemName: viewModel.isRivalOverlayEnabled ? "eye.fill" : "eye.slash.fill")
                .font(.body.bold())
                .foregroundStyle(viewModel.isRivalOverlayEnabled ? Color.accentColor : .primary)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            viewModel.isRivalOverlayEnabled
                ? "run.rivalOverlay.accessibility.on".localized
                : "run.rivalOverlay.accessibility.off".localized
        )
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

    private func finishIntro() {
        guard isPlayingIntro else { return }
        introTimeoutTask?.cancel()
        introTimeoutTask = nil
        isPlayingIntro = false
    }

    private func startIntroTimeoutIfNeeded() {
        introTimeoutTask?.cancel()
        introTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(Self.introTimeoutSeconds))
            guard !Task.isCancelled else { return }
            await MainActor.run { finishIntro() }
        }
    }

    private func presentRivalTerritoryBanner() {
        rivalTerritoryBannerTask?.cancel()

        withAnimation(.easeInOut(duration: 0.2)) {
            showRivalTerritoryBanner = true
        }

        rivalTerritoryBannerTask = Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showRivalTerritoryBanner = false
                }
            }
        }
    }
}

// MARK: - Run Map View (UIViewRepresentable)

struct RunMapView: UIViewRepresentable {
    let routePoints: [RoutePoint]
    let currentLocation: CLLocationCoordinate2D?
    let rivalTerritories: [Territory]
    let currentUserId: String?
    let showsRivalOverlay: Bool
    @Binding var isFollowingUser: Bool
    let recenterTrigger: Int
    var onIntroComplete: (() -> Void)?

    // Camera presets
    private static let introStartAltitude: CLLocationDistance = 11_000_000 // ~earth-from-space view
    private static let followAltitude: CLLocationDistance = 700            // close-up follow distance
    private static let followPitch: CGFloat = 50                           // 3D tilt
    private static let introDuration: TimeInterval = 3.6

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.mapType = .standard
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.showsCompass = false

        // Initial high-altitude camera centered on a neutral point;
        // coordinator will retarget it onto the user as soon as a fix arrives.
        let initialCamera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: 39.0, longitude: 35.0),
            fromDistance: Self.introStartAltitude,
            pitch: 0,
            heading: 0
        )
        mapView.setCamera(initialCamera, animated: false)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        if recenterTrigger != coordinator.lastRecenterTrigger {
            coordinator.lastRecenterTrigger = recenterTrigger
            coordinator.recenterOnUser(mapView)
        }

        let newCount = routePoints.count
        let rivalSignature = showsRivalOverlay
            ? rivalTerritories
                .sorted { $0.h3Index < $1.h3Index }
                .map { "\($0.h3Index):\($0.ownerColor)" }
                .joined(separator: "|")
            : ""
        let routeNeedsRefresh = routePoints.count >= 2
            && newCount != coordinator.lastRenderedPointCount
            && (newCount % 5 == 0 || newCount - coordinator.lastRenderedPointCount >= 5)
        let rivalNeedsRefresh = rivalSignature != coordinator.lastRivalOverlaySignature

        guard routeNeedsRefresh || rivalNeedsRefresh else { return }

        if routeNeedsRefresh {
            coordinator.lastRenderedPointCount = newCount
        }

        coordinator.lastRivalOverlaySignature = rivalSignature
        coordinator.currentUserId = currentUserId
        coordinator.rivalTerritoriesById = Dictionary(
            uniqueKeysWithValues: rivalTerritories.map { ($0.h3Index, $0) }
        )

        mapView.removeOverlays(mapView.overlays)

        if showsRivalOverlay {
            for territory in rivalTerritories.sorted(by: { $0.h3Index < $1.h3Index }) {
                if let polygon = MKPolygon.fromH3Index(territory.h3Index) {
                    mapView.addOverlay(polygon)
                }
            }
        }

        if routePoints.count >= 2 {
            let coordinates = routePoints.map(\.coordinate)
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RunMapView
        var lastRenderedPointCount = 0
        var lastRivalOverlaySignature = ""
        var rivalTerritoriesById: [String: Territory] = [:]
        var currentUserId: String?
        var lastRecenterTrigger: Int = 0
        private var hasPlayedIntro = false
        private var isApplyingProgrammaticChange = false

        init(parent: RunMapView) {
            self.parent = parent
            self.lastRecenterTrigger = parent.recenterTrigger
        }

        // MARK: - User Location & Cinematic Intro

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard !hasPlayedIntro,
                  let location = userLocation.location,
                  location.horizontalAccuracy > 0,
                  location.horizontalAccuracy < 200 else {
                return
            }
            hasPlayedIntro = true
            playCinematicIntro(on: mapView, target: location.coordinate)
        }

        private func playCinematicIntro(on mapView: MKMapView, target: CLLocationCoordinate2D) {
            // Snap initial camera to be high above the user (no animation),
            // so the cinematic descent always starts from above the runner.
            let startCamera = MKMapCamera(
                lookingAtCenter: target,
                fromDistance: RunMapView.introStartAltitude,
                pitch: 0,
                heading: 0
            )
            isApplyingProgrammaticChange = true
            mapView.setCamera(startCamera, animated: false)

            let endCamera = MKMapCamera(
                lookingAtCenter: target,
                fromDistance: RunMapView.followAltitude,
                pitch: RunMapView.followPitch,
                heading: 0
            )

            UIView.animate(
                withDuration: RunMapView.introDuration,
                delay: 0.05,
                options: [.curveEaseInOut]
            ) {
                mapView.camera = endCamera
            } completion: { [weak self] _ in
                guard let self = self else { return }
                mapView.setUserTrackingMode(.followWithHeading, animated: true)
                self.syncFollowingState(true)
                // Re-apply pitch — entering follow mode can flatten the camera.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if mapView.userTrackingMode != .none {
                        let pitched = mapView.camera.copy() as! MKMapCamera
                        pitched.pitch = RunMapView.followPitch
                        mapView.setCamera(pitched, animated: true)
                    }
                    self.isApplyingProgrammaticChange = false
                    self.parent.onIntroComplete?()
                }
            }
        }

        // MARK: - Recenter

        func recenterOnUser(_ mapView: MKMapView) {
            let target = mapView.userLocation.location?.coordinate
                ?? mapView.userLocation.coordinate

            // If we still don't have a usable fix, just toggle tracking mode.
            guard CLLocationCoordinate2DIsValid(target),
                  target.latitude != 0 || target.longitude != 0 else {
                mapView.setUserTrackingMode(.followWithHeading, animated: true)
                return
            }

            let camera = MKMapCamera(
                lookingAtCenter: target,
                fromDistance: RunMapView.followAltitude,
                pitch: RunMapView.followPitch,
                heading: mapView.camera.heading
            )

            isApplyingProgrammaticChange = true
            UIView.animate(
                withDuration: 0.7,
                delay: 0,
                options: [.curveEaseInOut]
            ) {
                mapView.camera = camera
            } completion: { [weak self] _ in
                guard let self = self else { return }
                mapView.setUserTrackingMode(.followWithHeading, animated: true)
                self.syncFollowingState(true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self.isApplyingProgrammaticChange = false
                }
            }
        }

        // MARK: - Tracking Mode Changes

        func mapView(
            _ mapView: MKMapView,
            didChange mode: MKUserTrackingMode,
            animated: Bool
        ) {
            guard hasPlayedIntro, !isApplyingProgrammaticChange else { return }
            // User dragged the map — MapKit drops tracking to .none.
            syncFollowingState(mode != .none)
        }

        private func syncFollowingState(_ following: Bool) {
            guard parent.isFollowingUser != following else { return }
            DispatchQueue.main.async { [weak self] in
                self?.parent.isFollowingUser = following
            }
        }

        // MARK: - Overlay Rendering

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }

            if let polygon = overlay as? MKPolygon,
               let h3Index = polygon.title,
               let territory = rivalTerritoriesById[h3Index] {
                let renderer = TerritoryOverlayRenderer(
                    polygon: polygon,
                    color: UIColor(Color(hex: territory.ownerColor) ?? .blue),
                    isDecaying: territory.isDecaying
                )
                renderer.applyStyle(
                    isSelected: false,
                    isOwnedByCurrentUser: territory.ownerId == currentUserId,
                    isDimmed: true
                )
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
