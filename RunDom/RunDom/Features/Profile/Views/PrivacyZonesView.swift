import SwiftUI
import MapKit

struct PrivacyZonesView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var store = PrivacyZonesStore.shared

    @State private var showAddSheet = false
    @State private var editingZone: PrivacyZone?
    @State private var pendingDelete: PrivacyZone?

    private let service = PrivacyZoneService()

    var body: some View {
        List {
            Section {
                Text("privacy.zones.explainer".localized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            if store.zones.isEmpty {
                Section {
                    emptyRow
                        .listRowBackground(Color.cardBackground)
                }
            } else {
                Section {
                    ForEach(store.zones) { zone in
                        Button {
                            editingZone = zone
                        } label: {
                            zoneRow(zone)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.cardBackground)
                    }
                    .onDelete { indexSet in
                        if let idx = indexSet.first {
                            pendingDelete = store.zones[idx]
                        }
                    }
                }
            }

            Section {
                Button {
                    showAddSheet = true
                } label: {
                    Label("privacy.zones.add".localized, systemImage: "plus.circle.fill")
                }
                .disabled(store.zones.count >= PrivacyZoneConstants.maxZonesPerUser)
                .listRowBackground(Color.cardBackground)
            } footer: {
                if store.zones.count >= PrivacyZoneConstants.maxZonesPerUser {
                    Text("privacy.zones.maxReached".localized(with: "\(PrivacyZoneConstants.maxZonesPerUser)"))
                        .font(.caption)
                } else {
                    Text("privacy.zones.maxHint".localized(with: "\(PrivacyZoneConstants.maxZonesPerUser)"))
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.surfacePrimary.ignoresSafeArea())
        .navigationTitle("settings.privacyZones".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            AddPrivacyZoneView(existing: nil) { name, lat, lon, radius in
                await save(name: name, lat: lat, lon: lon, radius: radius, replacing: nil)
            }
            .environmentObject(appState)
        }
        .sheet(item: $editingZone) { zone in
            AddPrivacyZoneView(existing: zone) { name, lat, lon, radius in
                await save(name: name, lat: lat, lon: lon, radius: radius, replacing: zone)
            }
            .environmentObject(appState)
        }
        .confirmationDialog(
            "privacy.zones.delete.confirm".localized(with: pendingDelete?.name ?? "privacy.zones.unnamed".localized),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("common.delete".localized, role: .destructive) {
                if let zone = pendingDelete { Task { await delete(zone) } }
                pendingDelete = nil
            }
            Button("common.cancel".localized, role: .cancel) {
                pendingDelete = nil
            }
        }
    }

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("privacy.zones.empty.title".localized)
                .font(.subheadline.weight(.semibold))
            Text("privacy.zones.empty.subtitle".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func zoneRow(_ zone: PrivacyZone) -> some View {
        HStack(spacing: 12) {
            zoneThumbnail(zone: zone)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(zone.name ?? "privacy.zones.unnamed".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("privacy.zones.radius".localized(with: "\(Int(zone.radius))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func zoneThumbnail(zone: PrivacyZone) -> some View {
        Map(
            initialPosition: .region(
                MKCoordinateRegion(
                    center: zone.coordinate,
                    latitudinalMeters: zone.radius * 3,
                    longitudinalMeters: zone.radius * 3
                )
            ),
            interactionModes: []
        ) {
            Annotation("", coordinate: zone.coordinate) {
                Circle()
                    .fill(Color.red.opacity(0.25))
                    .overlay(Circle().stroke(.red, lineWidth: 1.5))
                    .frame(width: 22, height: 22)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .disabled(true)
    }

    // MARK: - Actions

    private func save(
        name: String?,
        lat: Double,
        lon: Double,
        radius: Double,
        replacing: PrivacyZone?
    ) async {
        guard let userId = appState.currentUser?.id else { return }
        do {
            if let replacing {
                let updated = PrivacyZone(
                    id: replacing.id,
                    name: name?.isEmpty == false ? name : nil,
                    centerLatitude: lat,
                    centerLongitude: lon,
                    radius: radius,
                    createdAt: replacing.createdAt
                )
                try await service.updateZone(userId: userId, zone: updated)
            } else {
                _ = try await service.createZone(
                    userId: userId,
                    name: name,
                    latitude: lat,
                    longitude: lon,
                    radius: radius
                )
            }
            Haptics.notification(.success)
        } catch {
            AppLogger.firebase.error("Privacy zone save failed: \(error.localizedDescription)")
        }
    }

    private func delete(_ zone: PrivacyZone) async {
        guard let userId = appState.currentUser?.id else { return }
        do {
            try await service.deleteZone(userId: userId, zoneId: zone.id)
            Haptics.notification(.success)
        } catch {
            AppLogger.firebase.error("Privacy zone delete failed: \(error.localizedDescription)")
        }
    }
}
