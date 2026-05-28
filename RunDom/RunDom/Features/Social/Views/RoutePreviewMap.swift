import SwiftUI
import MapKit

/// Compact, non-interactive MKMapView showing a run polyline.
/// MKPolyline + MKMapView is used instead of the iOS 17 `Map` API to keep the
/// iOS 16 deployment floor.
struct RoutePreviewMap: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let strokeColor: UIColor

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.isUserInteractionEnabled = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsTraffic = false
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.strokeColor = strokeColor

        uiView.removeOverlays(uiView.overlays)
        guard coordinates.count > 1 else { return }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        uiView.addOverlay(polyline)

        let padding = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        uiView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: padding,
            animated: false
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(strokeColor: strokeColor)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var strokeColor: UIColor

        init(strokeColor: UIColor) {
            self.strokeColor = strokeColor
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = strokeColor
            renderer.lineWidth = 3.5
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
    }
}
