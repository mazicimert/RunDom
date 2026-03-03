import Foundation
import CoreLocation
import MapKit

extension MKPolygon {

    // MARK: - Create from H3 Index

    /// Creates an MKPolygon representing the hexagonal boundary of an H3 cell.
    /// The polygon's `title` is set to the H3 index for identification.
    static func fromH3Index(_ index: String) -> MKPolygon? {
        guard let coordinate = H3GridService.shared.coordinate(fromIndex: index) else {
            return nil
        }

        let resolution = H3GridService.shared.resolution(fromIndex: index)
        var boundary = coordinate.h3HexBoundary(resolution: resolution)

        let polygon = MKPolygon(coordinates: &boundary, count: boundary.count)
        polygon.title = index
        return polygon
    }

    // MARK: - Create from Coordinate

    /// Creates an MKPolygon for the hex cell at the given coordinate.
    static func hexagon(at coordinate: CLLocationCoordinate2D, resolution: Int = AppConstants.Location.h3Resolution) -> MKPolygon {
        var boundary = coordinate.h3HexBoundary(resolution: resolution)
        let index = coordinate.h3Index(resolution: resolution)

        let polygon = MKPolygon(coordinates: &boundary, count: boundary.count)
        polygon.title = index
        return polygon
    }

    // MARK: - Batch Creation

    /// Creates MKPolygons for a collection of H3 index strings.
    /// Skips any indices that cannot be parsed.
    static func hexagons(forIndices indices: [String]) -> [MKPolygon] {
        indices.compactMap { fromH3Index($0) }
    }

    // MARK: - H3 Index Accessor

    /// The H3 index stored in this polygon's title.
    /// Returns nil if the polygon was not created from an H3 cell.
    var h3Index: String? {
        title
    }
}
