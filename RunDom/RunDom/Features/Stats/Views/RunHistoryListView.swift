import MapKit
import SwiftUI
import UIKit

struct RunHistoryListView: View {
    let runs: [RunSession]
    let hasMore: Bool
    var onLoadMore: (() -> Void)? = nil
    var onSelectRun: ((RunSession) -> Void)? = nil
    var onDeleteRun: ((RunSession) -> Void)? = nil

    var body: some View {
        if runs.isEmpty {
            EmptyStateView(
                icon: "figure.run",
                title: "stats.noRuns".localized,
                subtitle: "stats.noRuns.subtitle".localized
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(runs) { run in
                    RunHistoryRow(
                        run: run,
                        onDelete: onDeleteRun.map { delete in
                            { delete(run) }
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.selection()
                        onSelectRun?(run)
                    }
                }

                if hasMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .onAppear {
                            onLoadMore?()
                        }
                }
            }
            .screenPadding()
        }
    }
}

// MARK: - Run History Row

private struct RunHistoryRow: View {
    let run: RunSession
    var onDelete: (() -> Void)? = nil

    private let cardHeight: CGFloat = 124
    private let thumbnailSize = CGSize(width: 114, height: 104)

    var body: some View {
        HStack(spacing: 14) {
            RunHistoryRouteThumbnail(run: run, size: thumbnailSize)
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    pointsBadge

                    Spacer(minLength: 0)

                    if let onDelete {
                        deleteButton(action: onDelete)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.top, 8)
                }

                HStack(spacing: 12) {
                    metricColumn(
                        value: run.distance.formattedCompactDistanceValueFromMeters,
                        title: "run.distance".localized
                    )

                    metricColumn(
                        value: run.duration.formattedDuration,
                        title: "run.duration".localized
                    )

                    metricColumn(
                        value: run.avgSpeed.formattedCompactSpeedValue,
                        title: "run.avgSpeed".localized
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.cardBackground.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }

    private var pointsBadge: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(run.trail.formattedTrail)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.primary)

            Text("trail.unit".localized)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive) {
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "trash")
                    .font(.caption.weight(.bold))
                Text("common.delete".localized)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.red)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.red.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.red.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("common.delete".localized)
    }

    private func metricColumn(value: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RunHistoryRouteThumbnail: View {
    let run: RunSession
    let size: CGSize

    @State private var snapshotImage: UIImage?

    private var modeTint: Color {
        run.mode == .boost ? .orange : .territoryBlue
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                thumbnailBackground

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.64),
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.58)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                dateBadge
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: -4)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )

            Image(systemName: run.mode == .boost ? "bolt.fill" : "figure.run")
                .font(.caption.weight(.bold))
                .foregroundStyle(modeTint)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.32))
                )
                .padding(10)
        }
        .task(id: "\(run.id)-\(Int(size.width))x\(Int(size.height))") {
            guard snapshotImage == nil else { return }
            snapshotImage = await RunHistoryMapThumbnailProvider.snapshot(for: run, size: size)
        }
    }

    private var dateBadge: some View {
        VStack(spacing: 3) {
            Text(run.startDate.formattedHistoryWeekday())
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .shadow(color: .black.opacity(0.34), radius: 6, y: 3)

            Text(run.startDate.formattedHistoryDayMonth())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .shadow(color: .black.opacity(0.28), radius: 4, y: 2)
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var thumbnailBackground: some View {
        if let snapshotImage {
            Image(uiImage: snapshotImage)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [
                    modeTint.opacity(0.22),
                    Color.surfacePrimary,
                    Color.cardBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary.opacity(0.18))
            )
        }
    }
}

private enum RunHistoryMapThumbnailProvider {
    private static let cache = NSCache<NSString, UIImage>()

    static func snapshot(for run: RunSession, size: CGSize) async -> UIImage? {
        let key = cacheKey(for: run, size: size)

        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        guard run.route.count >= 2 else { return nil }

        do {
            let image = try await renderSnapshot(for: run, size: size)
            cache.setObject(image, forKey: key)
            return image
        } catch {
            AppLogger.run.error("Run history thumbnail failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func cacheKey(for run: RunSession, size: CGSize) -> NSString {
        "\(run.id)-\(Int(size.width))x\(Int(size.height))" as NSString
    }

    private static func renderSnapshot(for run: RunSession, size: CGSize) async throws -> UIImage {
        let options = MKMapSnapshotter.Options()
        options.size = size
        options.scale = UIScreen.main.scale
        options.mapType = .mutedStandard
        options.showsBuildings = false
        options.pointOfInterestFilter = .excludingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        options.region = snapshotRegion(for: run.route, targetAspectRatio: size.width / size.height)

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot = try await start(snapshotter: snapshotter)
        return drawRoute(on: snapshot, route: run.route, scale: options.scale)
    }

    private static func start(snapshotter: MKMapSnapshotter) async throws -> MKMapSnapshotter.Snapshot {
        try await withCheckedThrowingContinuation { continuation in
            snapshotter.start { snapshot, error in
                if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: error ?? SnapshotError.snapshotFailed)
                }
            }
        }
    }

    private static func snapshotRegion(
        for route: [RoutePoint],
        targetAspectRatio: CGFloat
    ) -> MKCoordinateRegion {
        let coordinates = route.map(\.coordinate)

        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        let mapPoints = coordinates.map(MKMapPoint.init)
        let initialRect = mapPoints.reduce(MKMapRect.null) { partialRect, point in
            partialRect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }

        let baseWidth = max(initialRect.size.width, 180)
        let baseHeight = max(initialRect.size.height, 180)

        var fittedWidth = baseWidth
        var fittedHeight = baseHeight

        if fittedWidth / fittedHeight > targetAspectRatio {
            fittedHeight = fittedWidth / targetAspectRatio
        } else {
            fittedWidth = fittedHeight * targetAspectRatio
        }

        let paddingMultiplier = 1.22
        fittedWidth *= paddingMultiplier
        fittedHeight *= paddingMultiplier

        let fittedRect = MKMapRect(
            x: initialRect.midX - fittedWidth / 2,
            y: initialRect.midY - fittedHeight / 2,
            width: fittedWidth,
            height: fittedHeight
        )

        return MKCoordinateRegion(fittedRect)
    }

    private static func drawRoute(
        on snapshot: MKMapSnapshotter.Snapshot,
        route: [RoutePoint],
        scale: CGFloat
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale

        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size, format: format)

        return renderer.image { context in
            snapshot.image.draw(at: .zero)

            guard route.count >= 2 else { return }

            let points = route.map { snapshot.point(for: $0.coordinate) }
            let cgContext = context.cgContext

            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)
            cgContext.setLineWidth(6)
            cgContext.setStrokeColor(UIColor(Color.accentColor).cgColor)
            cgContext.setShadow(
                offset: CGSize(width: 0, height: 2),
                blur: 8,
                color: UIColor.black.withAlphaComponent(0.24).cgColor
            )

            cgContext.beginPath()
            cgContext.move(to: points[0])
            for point in points.dropFirst() {
                cgContext.addLine(to: point)
            }
            cgContext.strokePath()
        }
    }

    enum SnapshotError: Error {
        case snapshotFailed
    }
}

#Preview {
    RunHistoryListView(
        runs: [
            RunSession(
                id: "1",
                userId: "u1",
                mode: .normal,
                startDate: Date(),
                endDate: Date().addingTimeInterval(1800),
                distance: 5200,
                avgSpeed: 10.4,
                trail: 650,
                territoriesCaptured: 8,
                route: [
                    RoutePoint(latitude: 41.021, longitude: 28.974, timestamp: Date(), speed: 2.1, altitude: 20),
                    RoutePoint(latitude: 41.024, longitude: 28.981, timestamp: Date(), speed: 2.3, altitude: 18),
                    RoutePoint(latitude: 41.028, longitude: 28.989, timestamp: Date(), speed: 2.4, altitude: 22)
                ]
            ),
            RunSession(
                id: "2",
                userId: "u1",
                mode: .boost,
                startDate: Date().addingTimeInterval(-86400),
                endDate: Date().addingTimeInterval(-84600),
                distance: 3100,
                avgSpeed: 12.0,
                trail: 890,
                territoriesCaptured: 5,
                route: [
                    RoutePoint(latitude: 41.029, longitude: 28.966, timestamp: Date(), speed: 2.1, altitude: 14),
                    RoutePoint(latitude: 41.031, longitude: 28.973, timestamp: Date(), speed: 2.4, altitude: 18),
                    RoutePoint(latitude: 41.033, longitude: 28.985, timestamp: Date(), speed: 2.6, altitude: 16)
                ]
            )
        ],
        hasMore: false
    )
    .background(Color.surfacePrimary)
}
