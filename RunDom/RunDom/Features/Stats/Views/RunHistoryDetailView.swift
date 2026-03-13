import SwiftUI
import MapKit

struct RunHistoryDetailView: View {
    let run: RunSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Route Map
                if !run.route.isEmpty {
                    routeMap
                }

                // Mode Badge
                HStack {
                    Label(
                        run.mode == .boost ? "run.boostMode".localized : "run.normalMode".localized,
                        systemImage: run.mode == .boost ? "bolt.fill" : "figure.run"
                    )
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(run.mode == .boost ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                    .foregroundStyle(run.mode == .boost ? .orange : .blue)
                    .clipShape(Capsule())

                    Spacer()

                    Text(run.startDate.formattedDateTime())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .screenPadding()

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCardView(
                        icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                        value: run.distance.formattedDistanceFromMeters,
                        label: "run.distance".localized,
                        iconColor: .green
                    )
                    StatCardView(
                        icon: "clock.fill",
                        value: run.duration.formattedDuration,
                        label: "run.duration".localized,
                        iconColor: .blue
                    )
                    StatCardView(
                        icon: "speedometer",
                        value: run.avgSpeed.formattedSpeed,
                        label: "run.avgSpeed".localized,
                        iconColor: .purple
                    )
                    StatCardView(
                        icon: "flame.fill",
                        value: run.trail.formattedTrail,
                        label: "run.trailEarned".localized,
                        iconColor: .orange
                    )
                }
                .screenPadding()

                // Territories
                HStack(spacing: 12) {
                    Image(systemName: "hexagon.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(run.territoriesCaptured)")
                            .font(.headline)
                        Text("run.territoriesCaptured".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(run.uniqueZonesVisited)")
                            .font(.headline)
                        Text("stats.uniqueZones".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .cardStyle()
                .screenPadding()
            }
            .padding(.vertical)
        }
        .navigationTitle("run.summary".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Route Map

    private var routeMap: some View {
        Map {
            if run.route.count >= 2 {
                MapPolyline(coordinates: run.route.map { $0.coordinate })
                    .stroke(.blue, lineWidth: 4)
            }

            if let first = run.route.first {
                Annotation("run.startPoint".localized, coordinate: first.coordinate) {
                    Circle()
                        .fill(.green)
                        .frame(width: 12, height: 12)
                }
            }

            if let last = run.route.last {
                Annotation("run.endPoint".localized, coordinate: last.coordinate) {
                    Circle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous))
        .screenPadding()
        .allowsHitTesting(false)
    }
}

#Preview {
    NavigationStack {
        RunHistoryDetailView(run: RunSession(
            id: "1", userId: "u1", mode: .boost,
            startDate: Date().addingTimeInterval(-1800),
            endDate: Date(),
            distance: 5240, avgSpeed: 10.5, trail: 850,
            territoriesCaptured: 12, uniqueZonesVisited: 10, totalZonesVisited: 14
        ))
    }
}
