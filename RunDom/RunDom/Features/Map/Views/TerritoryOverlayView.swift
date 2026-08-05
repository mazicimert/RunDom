import SwiftUI
import MapKit

/// UIKit-based map overlay renderer for H3 territory hexagons.
/// Used by the MapKit coordinator to draw filled hex polygons with owner colors.
final class TerritoryOverlayRenderer: MKPolygonRenderer {

    private var territoryColor: UIColor
    private var isDecaying: Bool
    private var separatorColor = UIColor.territorySeparator(alpha: 0.32)
    private var separatorLineWidth: CGFloat = 0

    init(polygon: MKPolygon, color: UIColor, isDecaying: Bool = false) {
        self.territoryColor = color
        self.isDecaying = isDecaying
        super.init(overlay: polygon)

        lineJoin = .round
        lineCap = .round
    }

    /// Updates ownership-dependent colors without replacing the MapKit polygon.
    func updateTerritoryAppearance(color: UIColor, isDecaying: Bool) {
        territoryColor = color
        self.isDecaying = isDecaying
    }

    func applyStyle(isSelected: Bool, isOwnedByCurrentUser: Bool, isDimmed: Bool) {
        let fillAlpha: CGFloat
        let strokeAlpha: CGFloat
        let colorLineWidth: CGFloat
        let borderHighlightAmount: CGFloat

        if isDimmed {
            fillAlpha = 0.08
            strokeAlpha = 0.42
            colorLineWidth = 0.8
            separatorLineWidth = 1.5
            separatorColor = .territorySeparator(alpha: 0.18)
            borderHighlightAmount = 0.14
        } else if isSelected {
            fillAlpha = isDecaying ? 0.34 : 0.42
            strokeAlpha = 0.98
            colorLineWidth = isOwnedByCurrentUser ? 3.0 : 2.8
            separatorLineWidth = isOwnedByCurrentUser ? 4.6 : 4.4
            separatorColor = .territorySeparator(alpha: 0.56)
            borderHighlightAmount = 0.24
        } else if isOwnedByCurrentUser {
            fillAlpha = isDecaying ? 0.21 : 0.27
            strokeAlpha = 0.86
            colorLineWidth = 1.8
            separatorLineWidth = 3.0
            separatorColor = .territorySeparator(alpha: 0.30)
            borderHighlightAmount = 0.18
        } else {
            fillAlpha = isDecaying ? 0.14 : 0.19
            strokeAlpha = 0.80
            colorLineWidth = 1.45
            separatorLineWidth = 2.5
            separatorColor = .territorySeparator(alpha: 0.32)
            borderHighlightAmount = 0.18
        }

        let adaptiveHighlight = territoryColor.isDarkTerritoryColor
            ? max(borderHighlightAmount, 0.34)
            : borderHighlightAmount

        fillColor = territoryColor
            .blended(with: .white, amount: 0.05)
            .withAlphaComponent(fillAlpha)
        strokeColor = territoryColor
            .blended(with: .white, amount: adaptiveHighlight)
            .withAlphaComponent(strokeAlpha)
        lineWidth = colorLineWidth
        lineDashPattern = nil
    }

    override func draw(
        _ mapRect: MKMapRect,
        zoomScale: MKZoomScale,
        in context: CGContext
    ) {
        if path == nil {
            createPath()
        }

        if let separatorPath = path, separatorLineWidth > 0 {
            context.saveGState()
            context.addPath(separatorPath)
            context.setStrokeColor(separatorColor.cgColor)
            context.setLineWidth(separatorLineWidth / zoomScale)
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.strokePath()
            context.restoreGState()
        }

        super.draw(mapRect, zoomScale: zoomScale, in: context)
    }
}

private extension UIColor {
    static func territorySeparator(alpha: CGFloat) -> UIColor {
        UIColor(
            red: 10.0 / 255.0,
            green: 18.0 / 255.0,
            blue: 32.0 / 255.0,
            alpha: alpha
        )
    }

    var isDarkTerritoryColor: Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return false
        }

        func linearized(_ component: CGFloat) -> CGFloat {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        let luminance =
            0.2126 * linearized(red)
            + 0.7152 * linearized(green)
            + 0.0722 * linearized(blue)
        return luminance < 0.28
    }

    func blended(with color: UIColor, amount: CGFloat) -> UIColor {
        let fraction = min(max(amount, 0), 1)
        var sourceRed: CGFloat = 0
        var sourceGreen: CGFloat = 0
        var sourceBlue: CGFloat = 0
        var sourceAlpha: CGFloat = 0
        var targetRed: CGFloat = 0
        var targetGreen: CGFloat = 0
        var targetBlue: CGFloat = 0
        var targetAlpha: CGFloat = 0

        guard getRed(
            &sourceRed,
            green: &sourceGreen,
            blue: &sourceBlue,
            alpha: &sourceAlpha
        ), color.getRed(
            &targetRed,
            green: &targetGreen,
            blue: &targetBlue,
            alpha: &targetAlpha
        ) else {
            return self
        }

        return UIColor(
            red: sourceRed + (targetRed - sourceRed) * fraction,
            green: sourceGreen + (targetGreen - sourceGreen) * fraction,
            blue: sourceBlue + (targetBlue - sourceBlue) * fraction,
            alpha: sourceAlpha + (targetAlpha - sourceAlpha) * fraction
        )
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
