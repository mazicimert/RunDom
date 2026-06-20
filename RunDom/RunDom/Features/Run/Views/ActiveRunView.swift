import SwiftUI
import MapKit

struct ActiveRunView: View {
    @StateObject var viewModel: ActiveRunViewModel
    let onFinish: (RunSession) -> Void
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
    // 3D camera tilt during the run. Off by default — the camera tracks the runner from
    // a flat top-down framing. Users who prefer the cinematic tilt can opt in via the map
    // toggle; the choice persists across runs.
    @AppStorage(AppConstants.UserDefaultsKeys.runMapTiltEnabled) private var isTiltEnabled = false

    // Safety net: if no usable GPS fix arrives, start the run anyway after this
    // long so the screen never hangs on the space view. Comfortably longer than
    // the full intro (tile wait + hold + descent + settle) so a slightly delayed
    // fix never cuts the animation short.
    private static let introTimeoutSeconds: TimeInterval = 12.0

    var body: some View {
        ZStack {
            // Map background
            RunMapView(
                routePoints: viewModel.routePoints,
                currentLocation: viewModel.routePoints.last?.coordinate,
                rivalTerritories: viewModel.nearbyRivalTerritories,
                wonZoneIndices: viewModel.wonZones.sorted(),
                userColor: viewModel.userColor,
                currentUserId: viewModel.userId,
                showsRivalOverlay: viewModel.isRivalOverlayEnabled,
                isFollowingUser: $isFollowingUser,
                recenterTrigger: recenterTrigger,
                isTiltEnabled: isTiltEnabled,
                initialUserCoordinate: viewModel.introStartCoordinate,
                onIntroComplete: { finishIntro() }
            )
                .ignoresSafeArea()

            if shouldShowTopStatusStack {
                VStack {
                    topStatusStack
                    Spacer()
                }
                .padding(.top, 60)
            }

        }
        .animation(.easeInOut(duration: 0.3), value: isPlayingIntro)
        .overlay(alignment: .topTrailing) {
            if !isPlayingIntro {
                VStack(spacing: 12) {
                    rivalOverlayToggle

                    tiltToggle

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
                statsSheetDetents,
                selection: $statsDetent
            )
            .presentationBackgroundInteraction(
                .enabled(upThrough: viewModel.runState == .paused
                    ? RunStatsOverlayView.pausedCompactDetent
                    : RunStatsOverlayView.compactDetent)
            )
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
            .interactiveDismissDisabled()
        }
        .onAppear {
            guard !hasStartedRun else { return }
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
        .onChange(of: viewModel.runState) { _, newState in
            adjustStatsDetent(for: newState)
        }
        .onDisappear {
            rivalTerritoryBannerTask?.cancel()
            introTimeoutTask?.cancel()
        }
        .statusBarHidden(viewModel.runState == .running)
    }

    // MARK: - Top Status

    private var statsSheetDetents: Set<PresentationDetent> {
        if viewModel.runState == .paused {
            return [RunStatsOverlayView.pausedCompactDetent, RunStatsOverlayView.expandedDetent]
        }
        return [RunStatsOverlayView.compactDetent, RunStatsOverlayView.expandedDetent]
    }

    private func adjustStatsDetent(for runState: ActiveRunViewModel.RunState) {
        guard statsDetent != RunStatsOverlayView.expandedDetent else { return }
        statsDetent = runState == .paused
            ? RunStatsOverlayView.pausedCompactDetent
            : RunStatsOverlayView.compactDetent
    }

    private var shouldShowTopStatusStack: Bool {
        viewModel.gpsSignalLost
            || showRivalTerritoryBanner
            || (!viewModel.hasAlwaysLocationPermission && !isTrophyRunDemo)
    }

    private var topStatusStack: some View {
        VStack(spacing: 10) {
            if !viewModel.hasAlwaysLocationPermission && !isTrophyRunDemo {
                whenInUseWarningBanner
            }

            if viewModel.gpsSignalLost {
                gpsWarningBanner
            }

            if showRivalTerritoryBanner {
                rivalTerritoryBanner
            }
        }
    }

    private var isTrophyRunDemo: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-RunDomAutoStartTrophyRun")
        #else
        false
        #endif
    }

    private var whenInUseWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .foregroundStyle(.white)
            Text("run.whenInUse.banner".localized)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.92))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
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

    private var tiltToggle: some View {
        Button {
            Haptics.selection()
            isTiltEnabled.toggle()
        } label: {
            Image(systemName: isTiltEnabled ? "view.3d" : "view.2d")
                .font(.body.bold())
                .foregroundStyle(isTiltEnabled ? Color.accentColor : .primary)
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
            isTiltEnabled
                ? "run.tilt.accessibility.on".localized
                : "run.tilt.accessibility.off".localized
        )
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
        // The camera has descended from space and settled above the runner —
        // start the clock now (no separate 3-2-1 countdown).
        startRunIfNeeded()
    }

    private func startRunIfNeeded() {
        guard !hasStartedRun else { return }
        hasStartedRun = true
        viewModel.startRun()
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
    let wonZoneIndices: [String]
    let userColor: String
    let currentUserId: String?
    let showsRivalOverlay: Bool
    @Binding var isFollowingUser: Bool
    let recenterTrigger: Int
    /// When true the follow camera holds a 3D tilt; when false it tracks the runner from a
    /// flat top-down framing. User-controlled via the map's 2D/3D toggle.
    let isTiltEnabled: Bool
    /// Already-known runner coordinate so the cinematic descent can start as soon as
    /// the map appears, rather than waiting on MapKit's own user-location callback.
    var initialUserCoordinate: CLLocationCoordinate2D?
    var onIntroComplete: (() -> Void)?

    // Camera presets
    // NOTE: the starting altitude is deliberately a regional view (~200 km), NOT a country
    // (~2,000 km) or earth-from-space (~11,000 km) view. The black flashes during the approach
    // were MapKit running out of loaded tiles: a continuous fly across ~10 zoom levels never
    // lets the loader finish, and the coarse ancestor tile for the current view gets evicted
    // before the finer tiles arrive — leaving nothing to draw (black). ~200 km → 1.5 km is
    // only ~7 zoom levels, a span MapKit streams reliably with the ancestor always present
    // (so worst case is a brief blur, never black). Raising this re-introduces the black risk.
    private static let introStartAltitude: CLLocationDistance = 5_000_000  // continental view
    private static let followAltitude: CLLocationDistance = 8500           // follow distance
    private static let followPitchTilted: CGFloat = 50                     // 3D tilt (when enabled)
    /// Effective camera pitch for every framing below — the cinematic descent, touchdown, and
    /// live follow all read this so toggling 2D/3D flows through a single value.
    var followPitch: CGFloat { isTiltEnabled ? Self.followPitchTilted : 0 }
    private static let introHoldDuration: TimeInterval = 0.3               // beat at altitude before descending
    // The descent runs at an (almost) constant perceived zoom speed — geometric altitude
    // interpolation paced over this duration. The duration is chosen so the per-second zoom
    // factor stays within what MapKit can stream, so no frame ever outruns the tile loader
    // (which is what produced black tiles). A drone-like, uninterrupted glide — no pause.
    private static let introDuration: TimeInterval = 5.4                   // altitude → follow descent
    // Fraction of the descent spent easing in / out of the constant-speed glide (each end).
    // A trapezoidal velocity profile keeps a long constant-speed middle with soft start/stop,
    // so peak zoom speed stays low (≈1/(1-2·ramp)× the average) and tiles always keep up.
    private static let introVelocityRamp: Double = 0.22

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.mapType = .standard
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.showsCompass = false
        // Trim tile-rendering work so MapKit can keep up with the rapidly changing zoom
        // level during the descent — POI labels and 3D buildings are the heaviest tile
        // content and the biggest contributors to black/unloaded frames. Kept off for the
        // whole run too: re-enabling on intro completion would trigger a tile reload flash
        // right as follow mode engages, and the H3 territory overlays are the focus anyway.
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = false

        // Detect user pan / pinch so we can drop manual follow (and reveal the recenter button)
        // the moment the runner moves the map themselves. These run alongside MapKit's own
        // gesture handling (see UIGestureRecognizerDelegate) without swallowing it.
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.userInteractedWithMap(_:))
        )
        pan.delegate = context.coordinator
        mapView.addGestureRecognizer(pan)
        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.userInteractedWithMap(_:))
        )
        pinch.delegate = context.coordinator
        mapView.addGestureRecognizer(pinch)

        // Initial high-altitude camera. Center it on the runner if we already know
        // where they are; otherwise fall back to a neutral point until a fix arrives.
        // Request the final follow pitch from the very first frame: MapKit clamps pitch to
        // ~0 at high altitude and lets it grow as the camera descends, so the tilt eases in
        // naturally *as part of the descent* instead of being a separate tilt-out step at the
        // end (which both looked like a pull-back and flashed black as it revealed the
        // horizon). Rendering the pitched view up front also pre-loads the horizon tiles.
        let initialCenter = initialUserCoordinate
            ?? CLLocationCoordinate2D(latitude: 39.0, longitude: 35.0)
        let initialCamera = MKMapCamera(
            lookingAtCenter: initialCenter,
            fromDistance: Self.introStartAltitude,
            pitch: followPitch,
            heading: 0
        )
        mapView.setCamera(initialCamera, animated: false)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        // Kick off the space→ground descent as soon as we have a coordinate to aim at.
        coordinator.startIntroIfReady(on: mapView)

        // The user flipped the 2D/3D toggle mid-run — ease the live camera to the new pitch.
        if isTiltEnabled != coordinator.lastAppliedTiltEnabled {
            coordinator.lastAppliedTiltEnabled = isTiltEnabled
            coordinator.applyTiltPreference(on: mapView)
        }

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
        let wonSignature = "\(userColor)#\(wonZoneIndices.joined(separator: "|"))"
        let routeNeedsRefresh = routePoints.count >= 2
            && newCount != coordinator.lastRenderedPointCount
            && (newCount % 5 == 0 || newCount - coordinator.lastRenderedPointCount >= 5)
        let rivalNeedsRefresh = rivalSignature != coordinator.lastRivalOverlaySignature
        let wonNeedsRefresh = wonSignature != coordinator.lastWonOverlaySignature

        guard routeNeedsRefresh || rivalNeedsRefresh || wonNeedsRefresh else { return }

        if routeNeedsRefresh {
            coordinator.lastRenderedPointCount = newCount
        }

        // Cells won since the last refresh — these get the one-shot paint splash.
        let incomingWon = Set(wonZoneIndices)
        let newlyWon = incomingWon.subtracting(coordinator.wonCellIndices)

        coordinator.lastRivalOverlaySignature = rivalSignature
        coordinator.lastWonOverlaySignature = wonSignature
        coordinator.currentUserId = currentUserId
        coordinator.rivalTerritoriesById = Dictionary(
            uniqueKeysWithValues: rivalTerritories.map { ($0.h3Index, $0) }
        )
        coordinator.wonCellIndices = incomingWon
        coordinator.wonCellColor = userColor

        mapView.removeOverlays(mapView.overlays)

        // Rival territories (dim) sit underneath the user's own painted cells.
        if showsRivalOverlay {
            for territory in rivalTerritories.sorted(by: { $0.h3Index < $1.h3Index }) {
                if let polygon = MKPolygon.fromH3Index(territory.h3Index) {
                    mapView.addOverlay(polygon)
                }
            }
        }

        // The runner's won cells, painted in their color (always visible).
        for index in wonZoneIndices where coordinator.rivalTerritoriesById[index] == nil {
            if let polygon = MKPolygon.fromH3Index(index) {
                mapView.addOverlay(polygon)
            }
        }

        if routePoints.count >= 2 {
            let coordinates = routePoints.map(\.coordinate)
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }

        // Celebrate freshly won cells with a paint splash on top of the new overlay.
        if !newlyWon.isEmpty {
            coordinator.playWonCellSplashes(
                on: mapView,
                indices: newlyWon,
                color: UIColor(Color(hex: userColor) ?? .blue)
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    static func dismantleUIView(_ uiView: MKMapView, coordinator: Coordinator) {
        coordinator.cancelIntro()
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: RunMapView
        var lastRenderedPointCount = 0
        var lastRivalOverlaySignature = ""
        var lastWonOverlaySignature = ""
        var rivalTerritoriesById: [String: Territory] = [:]
        var wonCellIndices: Set<String> = []
        var wonCellColor: String = ""
        var currentUserId: String?
        var lastRecenterTrigger: Int = 0
        var lastAppliedTiltEnabled: Bool
        private var hasPlayedIntro = false
        private var isApplyingProgrammaticChange = false
        // Manual follow: we keep the camera locked onto the runner ourselves (centered, at the
        // fixed follow altitude + pitch) instead of using MKMapView's `userTrackingMode`. The
        // built-in tracking mode reframes the camera to MapKit's own default follow distance on
        // entry — a visible zoom-out / pull-back — and it can't be overridden without a
        // programmatic `setCamera`, which in turn drops tracking back to `.none`. Driving the
        // follow ourselves keeps the exact close-up framing with no pull-back, ever.
        private var isUserFollowActive = false

        // Cinematic intro animation state (driven frame-by-frame via CADisplayLink).
        private var introDisplayLink: CADisplayLink?
        private var introStartTime: CFTimeInterval = 0
        private weak var introMapView: MKMapView?
        private var introTarget = CLLocationCoordinate2D()
        private var introAwaitingTiles = false

        init(parent: RunMapView) {
            self.parent = parent
            self.lastRecenterTrigger = parent.recenterTrigger
            self.lastAppliedTiltEnabled = parent.isTiltEnabled
        }

        // MARK: - User Location & Cinematic Intro

        /// Starts the descent from the already-known runner coordinate (preferred —
        /// it's available immediately). Called from `updateUIView`.
        func startIntroIfReady(on mapView: MKMapView) {
            guard !hasPlayedIntro,
                  let target = parent.initialUserCoordinate,
                  CLLocationCoordinate2DIsValid(target),
                  target.latitude != 0 || target.longitude != 0 else {
                return
            }
            hasPlayedIntro = true
            playCinematicIntro(on: mapView, target: target)
        }

        /// Fallback intro trigger + manual-follow driver. Before the intro plays this starts
        /// the descent on the first usable fix; afterwards it keeps the camera locked onto the
        /// runner (when follow is active and we aren't mid-animation).
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            if !hasPlayedIntro {
                guard let location = userLocation.location,
                      location.horizontalAccuracy > 0,
                      location.horizontalAccuracy < 200 else {
                    return
                }
                hasPlayedIntro = true
                playCinematicIntro(on: mapView, target: location.coordinate)
                return
            }

            guard isUserFollowActive,
                  !isApplyingProgrammaticChange,
                  introDisplayLink == nil,
                  let location = userLocation.location,
                  CLLocationCoordinate2DIsValid(location.coordinate) else {
                return
            }
            followCamera(on: mapView, location: location)
        }

        /// Drives the camera from a "from space" altitude straight down onto the runner.
        ///
        /// We step the camera ourselves via `CADisplayLink` instead of assigning the
        /// end camera inside `UIView.animate`: MapKit won't render a continuous fly-in
        /// across the enormous space→ground range that way (it jumps / skips the far
        /// portion, so the "from space" beat is never seen). Frame-by-frame stepping
        /// with geometric altitude interpolation keeps the perceived zoom speed steady
        /// and guarantees the descent is actually visible.
        private func playCinematicIntro(on mapView: MKMapView, target: CLLocationCoordinate2D) {
            guard introDisplayLink == nil, !introAwaitingTiles else { return }
            introMapView = mapView
            introTarget = target

            // Lock high above the runner. Request the final follow pitch up front (MapKit
            // clamps it to ~0 at this altitude and grows it during the descent) so the tilt
            // eases in as part of the approach rather than as a separate tilt-out at the end.
            let startCamera = MKMapCamera(
                lookingAtCenter: target,
                fromDistance: RunMapView.introStartAltitude,
                pitch: parent.followPitch,
                heading: 0
            )
            isApplyingProgrammaticChange = true
            mapView.setCamera(startCamera, animated: false)

            // Let the wide "from space" view finish loading its tiles before descending,
            // otherwise the first frames flash dark/unloaded areas. We begin on the first
            // completed render (see mapViewDidFinishRenderingMap) or after a short fallback
            // so we never stall if MapKit doesn't report a full render.
            introAwaitingTiles = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.beginIntroDescent()
            }
        }

        /// Begins the frame-by-frame descent once the initial tiles are ready.
        private func beginIntroDescent() {
            guard introAwaitingTiles else { return }
            introAwaitingTiles = false
            introStartTime = CACurrentMediaTime()
            let link = CADisplayLink(target: self, selector: #selector(stepCinematicIntro))
            link.add(to: .main, forMode: .common)
            introDisplayLink = link
        }

        func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
            guard introAwaitingTiles, fullyRendered else { return }
            beginIntroDescent()
        }

        @objc private func stepCinematicIntro() {
            guard let mapView = introMapView else {
                completeCinematicIntro()
                return
            }

            let elapsed = CACurrentMediaTime() - introStartTime
            let descentEnd = RunMapView.introHoldDuration + RunMapView.introDuration

            // Linear real-time fraction of the descent, shaped by a trapezoidal velocity
            // profile: soft acceleration, a long constant-speed glide, soft deceleration.
            // This bounds peak zoom speed so MapKit's tile loader never falls behind — a
            // continuous, premium glide with no pause and no black frames.
            let f = min(max((elapsed - RunMapView.introHoldDuration) / RunMapView.introDuration, 0), 1)
            let t = Coordinator.trapezoidEase(f, ramp: RunMapView.introVelocityRamp)
            // Geometric (log-space) altitude interpolation → constant perceived zoom speed
            // across the descent range while `t` advances linearly through the glide.
            let altitude = RunMapView.introStartAltitude
                * pow(RunMapView.followAltitude / RunMapView.introStartAltitude, t)

            // Hold the final follow pitch for the whole descent. MapKit clamps pitch toward 0
            // while high and opens it up as the altitude drops, so the camera tilts in smoothly
            // *during* the approach and arrives directly at the run framing — no separate
            // tilt-out (which read as a pull-back and revealed un-loaded horizon tiles → black).
            mapView.camera = MKMapCamera(
                lookingAtCenter: introTarget,
                fromDistance: altitude,
                pitch: parent.followPitch,
                heading: 0
            )

            if elapsed >= descentEnd {
                completeCinematicIntro()
            }
        }

        private func completeCinematicIntro() {
            introDisplayLink?.invalidate()
            introDisplayLink = nil

            guard let mapView = introMapView else {
                isApplyingProgrammaticChange = false
                parent.onIntroComplete?()
                return
            }
            introMapView = nil

            // Touchdown: the descent already arrived at the exact run framing (follow altitude
            // AND pitch), so this is just a small animated recenter onto the live position — no
            // tilt change and no altitude change, hence no pull-back. We also do NOT force a
            // rotation to the runner's course here (a heading snap would swing to a new
            // direction and expose un-loaded horizon tiles); we keep the current heading and
            // let follow mode rotate gradually once the runner is actually moving.
            let liveCoord = mapView.userLocation.location?.coordinate
            let center = (liveCoord.map(CLLocationCoordinate2DIsValid) == true) ? liveCoord! : introTarget
            let landed = MKMapCamera(
                lookingAtCenter: center,
                fromDistance: RunMapView.followAltitude,
                pitch: parent.followPitch,
                heading: mapView.camera.heading
            )

            UIView.animate(
                withDuration: 0.65,
                delay: 0,
                options: [.curveEaseInOut]
            ) {
                mapView.camera = landed
            } completion: { [weak self] _ in
                guard let self = self else { return }
                self.beginUserFollow(on: mapView)
                // Hold the programmatic-change guard until the follow transition settles, so
                // its region/tracking callbacks aren't mistaken for a user drag.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.isApplyingProgrammaticChange = false
                }
            }

            // The camera has touched down above the runner — start the run clock now. The
            // animated landing tilt continues underneath without delaying the run.
            parent.onIntroComplete?()
        }

        /// Starts manual heading-up follow: from now on every location update keeps the camera
        /// centered on the runner at the fixed follow altitude + pitch. No `userTrackingMode`,
        /// so MapKit never reframes / pulls back.
        private func beginUserFollow(on mapView: MKMapView) {
            isUserFollowActive = true
            syncFollowingState(true)
            if let location = mapView.userLocation.location,
               CLLocationCoordinate2DIsValid(location.coordinate) {
                followCamera(on: mapView, location: location)
            }
        }

        /// Moves the camera to keep the runner centered at the fixed close-up framing. Uses
        /// MapKit's own animated camera move (interruptible by user gestures, and — since we
        /// never enter tracking mode — it just goes to exactly the camera we ask for, with no
        /// pull-back). Heading follows the course only when it's valid, so a stationary runner
        /// doesn't make the map spin.
        private func followCamera(on mapView: MKMapView, location: CLLocation) {
            let heading = location.course >= 0 ? location.course : mapView.camera.heading
            let camera = MKMapCamera(
                lookingAtCenter: location.coordinate,
                fromDistance: RunMapView.followAltitude,
                pitch: parent.followPitch,
                heading: heading
            )
            mapView.setCamera(camera, animated: true)
        }

        /// User panned or pinched the map — stop following and surface the recenter button.
        @objc func userInteractedWithMap(_ recognizer: UIGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                guard isUserFollowActive else { return }
                isUserFollowActive = false
                syncFollowingState(false)
            default:
                break
            }
        }

        // Let our pan/pinch recognizers fire alongside MapKit's built-in map gestures.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        /// Trapezoidal velocity profile over a normalized time fraction `f` ∈ [0, 1].
        /// Velocity ramps up over `[0, ramp]`, stays constant over `[ramp, 1 - ramp]`, then
        /// ramps down over `[1 - ramp, 1]`. Returns the integrated position (also in [0, 1])
        /// and is C¹-continuous, so the camera accelerates and settles smoothly with no jolt.
        /// Peak speed is only `1 / (1 - ramp)` × the average, keeping the zoom rate low enough
        /// that MapKit's tile loader never falls behind during the close-up approach.
        private static func trapezoidEase(_ f: Double, ramp: Double) -> Double {
            let r = min(max(ramp, 0.0001), 0.5)
            let vMax = 1.0 / (1.0 - r)            // peak velocity so the area under v(t) == 1
            if f <= r {
                return vMax * f * f / (2 * r)     // accelerating
            } else if f < 1 - r {
                return vMax * (f - r / 2)         // constant speed
            } else {
                let d = 1 - f
                return 1 - vMax * d * d / (2 * r) // decelerating
            }
        }

        /// Stops the descent without firing completion — used when the map view is torn
        /// down mid-intro (also breaks the CADisplayLink → Coordinator retain).
        func cancelIntro() {
            introAwaitingTiles = false
            introDisplayLink?.invalidate()
            introDisplayLink = nil
            introMapView = nil
        }

        // MARK: - Tilt

        /// Animates the live camera to the current pitch preference, keeping the existing
        /// center, distance and heading. If follow is active the next location update will
        /// naturally hold the new pitch too (followCamera reads parent.followPitch).
        func applyTiltPreference(on mapView: MKMapView) {
            // Don't fight the cinematic descent — it already renders at the active pitch and
            // the toggle isn't reachable until the intro completes.
            guard introDisplayLink == nil, !introAwaitingTiles else { return }

            let current = mapView.camera
            let camera = MKMapCamera(
                lookingAtCenter: current.centerCoordinate,
                fromDistance: current.centerCoordinateDistance,
                pitch: parent.followPitch,
                heading: current.heading
            )

            isApplyingProgrammaticChange = true
            UIView.animate(
                withDuration: 0.45,
                delay: 0,
                options: [.curveEaseInOut]
            ) {
                mapView.camera = camera
            } completion: { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.isApplyingProgrammaticChange = false
                }
            }
        }

        // MARK: - Recenter

        func recenterOnUser(_ mapView: MKMapView) {
            let target = mapView.userLocation.location?.coordinate
                ?? mapView.userLocation.coordinate

            // If we still don't have a usable fix, just engage follow.
            guard CLLocationCoordinate2DIsValid(target),
                  target.latitude != 0 || target.longitude != 0 else {
                beginUserFollow(on: mapView)
                return
            }

            let camera = MKMapCamera(
                lookingAtCenter: target,
                fromDistance: RunMapView.followAltitude,
                pitch: parent.followPitch,
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
                // Engage follow without the pull-back (see beginUserFollow): entering tracking
                // with `animated: true` here would zoom back out to MapKit's default framing.
                self.beginUserFollow(on: mapView)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self.isApplyingProgrammaticChange = false
                }
            }
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
               wonCellIndices.contains(h3Index) {
                let renderer = TerritoryOverlayRenderer(
                    polygon: polygon,
                    color: UIColor(Color(hex: wonCellColor) ?? .blue)
                )
                renderer.applyStyle(
                    isSelected: false,
                    isOwnedByCurrentUser: true,
                    isDimmed: false
                )
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

        // MARK: - Won Cell Paint Splash

        func playWonCellSplashes(on mapView: MKMapView, indices: Set<String>, color: UIColor) {
            for index in indices {
                playWonCellSplash(on: mapView, index: index, color: color)
            }
        }

        /// Plays a short pop-and-fade hexagon over a freshly won cell, drawn on top of the
        /// permanent overlay so the cell reads as being "stamped" onto the map.
        private func playWonCellSplash(on mapView: MKMapView, index: String, color: UIColor) {
            guard let polygon = MKPolygon.fromH3Index(index) else { return }
            let pointCount = polygon.pointCount
            guard pointCount >= 3 else { return }
            let mapPoints = polygon.points()

            // First pass: screen-space centroid of the hexagon.
            var centroid = CGPoint.zero
            var screenPoints: [CGPoint] = []
            screenPoints.reserveCapacity(pointCount)
            for i in 0..<pointCount {
                let p = mapView.convert(mapPoints[i].coordinate, toPointTo: mapView)
                screenPoints.append(p)
                centroid.x += p.x
                centroid.y += p.y
            }
            centroid.x /= CGFloat(pointCount)
            centroid.y /= CGFloat(pointCount)

            // Build the path relative to the centroid so the layer can scale around it.
            let path = UIBezierPath()
            for (i, p) in screenPoints.enumerated() {
                let rel = CGPoint(x: p.x - centroid.x, y: p.y - centroid.y)
                if i == 0 { path.move(to: rel) } else { path.addLine(to: rel) }
            }
            path.close()

            let layer = CAShapeLayer()
            layer.path = path.cgPath
            layer.bounds = .zero            // anchor (0.5,0.5) of a zero rect → centroid
            layer.position = centroid
            layer.fillColor = color.withAlphaComponent(0.55).cgColor
            layer.strokeColor = color.withAlphaComponent(0.95).cgColor
            layer.lineWidth = 3
            layer.lineJoin = .round
            mapView.layer.addSublayer(layer)

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.2
            scale.toValue = 1.0
            scale.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0.0, 1.0, 1.0, 0.0]
            opacity.keyTimes = [0.0, 0.18, 0.6, 1.0]

            let group = CAAnimationGroup()
            group.animations = [scale, opacity]
            group.duration = 0.6
            group.isRemovedOnCompletion = false
            group.fillMode = .forwards

            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak layer] in
                layer?.removeFromSuperlayer()
            }
            layer.add(group, forKey: "wonCellSplash")
            CATransaction.commit()
        }
    }
}
