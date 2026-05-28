import SwiftUI
import MapKit
import CoreLocation

struct AddPrivacyZoneView: View {
    let existing: PrivacyZone?
    let onSave: (_ name: String?, _ latitude: Double, _ longitude: Double, _ radius: Double) async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition
    @State private var centerCoordinate: CLLocationCoordinate2D
    @State private var radius: Double
    @State private var name: String
    @State private var isSaving = false
    @State private var hasLocatedUser = false

    private let locationManager = CLLocationManager()

    init(
        existing: PrivacyZone?,
        onSave: @escaping (_ name: String?, _ latitude: Double, _ longitude: Double, _ radius: Double) async -> Void
    ) {
        self.existing = existing
        self.onSave = onSave

        // Initial centre: edit → existing zone, create → Istanbul fallback
        // (overridden once CoreLocation returns the current location).
        let initialCenter = existing?.coordinate
            ?? CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
        let initialRadius = existing?.radius ?? PrivacyZoneConstants.defaultRadius
        let zoom = initialRadius * 4

        _cameraPosition = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: initialCenter,
                    latitudinalMeters: zoom,
                    longitudinalMeters: zoom
                )
            )
        )
        _centerCoordinate = State(initialValue: initialCenter)
        _radius = State(initialValue: initialRadius)
        _name = State(initialValue: existing?.name ?? "")
        // If we're editing we already have a position — don't auto-jump.
        _hasLocatedUser = State(initialValue: existing != nil)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                mapSection
                controlsSection
            }
            .background(Color.surfacePrimary.ignoresSafeArea())
            .navigationTitle(existing == nil
                             ? "privacy.zones.add.title".localized
                             : "privacy.zones.edit.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("common.save".localized).fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .task {
                if !hasLocatedUser {
                    await loadCurrentLocation()
                }
            }
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        ZStack(alignment: .center) {
            Map(position: $cameraPosition) {
                // Shaded preview circle anchored to the LIVE camera centre so
                // the user sees the masked area update as they pan/slide.
                MapCircle(center: centerCoordinate, radius: radius)
                    .foregroundStyle(Color.red.opacity(0.18))
                    .stroke(Color.red.opacity(0.7), lineWidth: 1.5)
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .onMapCameraChange(frequency: .continuous) { context in
                centerCoordinate = context.camera.centerCoordinate
            }

            // Fixed centre pin — overlays the map at its centre regardless of
            // where the map is panned. This is the "Google Maps address picker"
            // pattern: the pin stays put, the map moves underneath.
            VStack(spacing: 0) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.red)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                // Visual tail so it reads as a dropped pin.
                Image(systemName: "triangle.fill")
                    .font(.system(size: 10))
                    .rotationEffect(.degrees(180))
                    .foregroundStyle(.red)
                    .offset(y: -2)
            }
            .offset(y: -18) // anchors the bottom of the tail to the centre

            // Coordinate readout — tiny hint that gives the user feedback that
            // the centre is actively tracking.
            VStack {
                Spacer()
                Text(String(format: "%.5f, %.5f", centerCoordinate.latitude, centerCoordinate.longitude))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Radius slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("privacy.zones.radius.label".localized)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(radius)) m")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: $radius,
                    in: PrivacyZoneConstants.minRadius...PrivacyZoneConstants.maxRadius,
                    step: 25
                )
                HStack {
                    Text("\(Int(PrivacyZoneConstants.minRadius)) m")
                    Spacer()
                    Text("\(Int(PrivacyZoneConstants.maxRadius)) m")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("privacy.zones.name.label".localized)
                    .font(.subheadline.weight(.semibold))
                TextField("privacy.zones.name.placeholder".localized, text: $name)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.cardBackground)
                    )
            }

            Button {
                Task { await jumpToCurrentLocation() }
            } label: {
                Label(
                    "privacy.zones.useMyLocation".localized,
                    systemImage: "location.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, AppConstants.UI.screenPadding)
        .padding(.vertical, 18)
        .background(Color.surfacePrimary)
    }

    // MARK: - Location

    private func loadCurrentLocation() async {
        // Permission has already been requested during onboarding for run
        // tracking, so we just attempt to read. If denied we keep the fallback
        // Istanbul region — the user can pan manually.
        let status = locationManager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            hasLocatedUser = true
            return
        }
        if let location = locationManager.location {
            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: location.coordinate,
                        latitudinalMeters: radius * 4,
                        longitudinalMeters: radius * 4
                    )
                )
            }
        }
        hasLocatedUser = true
    }

    private func jumpToCurrentLocation() async {
        let status = locationManager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse,
              let location = locationManager.location else {
            return
        }
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: radius * 4,
                    longitudinalMeters: radius * 4
                )
            )
        }
        Haptics.impact(.light)
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        await onSave(
            name.isEmpty ? nil : name,
            centerCoordinate.latitude,
            centerCoordinate.longitude,
            radius
        )
        isSaving = false
        dismiss()
    }
}
