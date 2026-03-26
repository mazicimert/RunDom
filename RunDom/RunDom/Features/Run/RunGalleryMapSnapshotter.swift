import CoreLocation
import MapKit
import SwiftUI
import UIKit

enum RunGalleryMapSnapshotter {
    static func snapshot(for session: RunSession, size: CGSize) async throws -> UIImage {
        let options = MKMapSnapshotter.Options()
        options.size = size
        options.scale = UIScreen.main.scale
        options.mapType = .mutedStandard
        options.showsBuildings = true
        options.pointOfInterestFilter = .includingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        options.region = snapshotRegion(for: session.route)

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot = try await start(snapshotter: snapshotter)
        return drawRoute(on: snapshot, route: session.route, scale: options.scale)
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

    private static func snapshotRegion(for route: [RoutePoint]) -> MKCoordinateRegion {
        let coordinates = route.map(\.coordinate)

        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        if coordinates.count == 1, let coordinate = coordinates.first {
            return MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
            )
        }

        let mapPoints = coordinates.map(MKMapPoint.init)
        let initialRect = mapPoints.reduce(MKMapRect.null) { partialRect, point in
            partialRect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }

        let baseWidth = max(initialRect.size.width, 250)
        let baseHeight = max(initialRect.size.height, 250)
        let targetAspectRatio = 1080.0 / 1350.0

        var fittedWidth = baseWidth
        var fittedHeight = baseHeight

        if fittedWidth / fittedHeight > targetAspectRatio {
            fittedHeight = fittedWidth / targetAspectRatio
        } else {
            fittedWidth = fittedHeight * targetAspectRatio
        }

        let paddingMultiplier = 1.18
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
            cgContext.setLineWidth(12)
            cgContext.setStrokeColor(UIColor(Color.accentColor).cgColor)
            cgContext.setShadow(offset: CGSize(width: 0, height: 4), blur: 12, color: UIColor.black.withAlphaComponent(0.28).cgColor)

            cgContext.beginPath()
            cgContext.move(to: points[0])
            for point in points.dropFirst() {
                cgContext.addLine(to: point)
            }
            cgContext.strokePath()

            cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            drawMarker(at: points.first ?? .zero, fill: UIColor.white, stroke: UIColor.systemBlue, in: cgContext)
            drawMarker(at: points.last ?? .zero, fill: UIColor.white, stroke: UIColor.systemGreen, in: cgContext)
        }
    }

    private static func drawMarker(at point: CGPoint, fill: UIColor, stroke: UIColor, in context: CGContext) {
        let outerRect = CGRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28)
        let innerRect = CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)

        context.setFillColor(stroke.cgColor)
        context.fillEllipse(in: outerRect)
        context.setFillColor(fill.cgColor)
        context.fillEllipse(in: innerRect)
    }

    enum SnapshotError: Error {
        case snapshotFailed
    }
}
