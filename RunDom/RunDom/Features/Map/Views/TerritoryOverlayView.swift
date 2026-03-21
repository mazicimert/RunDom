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

        lineJoin = .round
        lineCap = .round
    }

    func applyStyle(isSelected: Bool, isOwnedByCurrentUser: Bool, isDimmed: Bool) {
        let fillAlpha: CGFloat
        let strokeAlpha: CGFloat

        if isDimmed {
            fillAlpha = 0.08
            strokeAlpha = 0.18
        } else if isSelected {
            fillAlpha = isDecaying ? 0.34 : 0.52
            strokeAlpha = 1.0
        } else if isOwnedByCurrentUser {
            fillAlpha = isDecaying ? 0.22 : 0.34
            strokeAlpha = 0.9
        } else {
            fillAlpha = isDecaying ? 0.14 : 0.22
            strokeAlpha = 0.62
        }

        fillColor = territoryColor.withAlphaComponent(fillAlpha)
        strokeColor = territoryColor.withAlphaComponent(strokeAlpha)
        lineWidth = isSelected ? (isOwnedByCurrentUser ? 4.8 : 4.0) : (isOwnedByCurrentUser ? 3.0 : 1.6)
        lineDashPattern = isOwnedByCurrentUser ? nil : [6 as NSNumber, 4 as NSNumber]
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
