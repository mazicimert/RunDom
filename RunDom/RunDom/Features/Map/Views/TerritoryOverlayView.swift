import SwiftUI
import MapKit

/// UIKit-based map overlay renderer for H3 territory hexagons.
/// Used by the MapKit coordinator to draw filled hex polygons with owner colors.
final class TerritoryOverlayRenderer: MKPolygonRenderer {

    let territoryColor: UIColor
    let isDecaying: Bool

    init(polygon: MKPolygon, color: UIColor, isDecaying: Bool = false) {
        self.territoryColor = color
        self.isDecaying = isDecaying
        super.init(overlay: polygon)

        fillColor = color.withAlphaComponent(isDecaying ? 0.25 : 0.4)
        strokeColor = color.withAlphaComponent(isDecaying ? 0.4 : 0.8)
        lineWidth = 1.5
    }
}

// MARK: - Territory Polygon Data

/// Associates an MKPolygon with its territory metadata for rendering.
struct TerritoryPolygon: Identifiable {
    let id: String
    let polygon: MKPolygon
    let territory: Territory

    init?(territory: Territory) {
        guard let polygon = MKPolygon.fromH3Index(territory.h3Index) else { return nil }
        self.id = territory.h3Index
        self.polygon = polygon
        self.territory = territory
    }
}
