import Foundation
import CoreLocation
import MapKit

/// Service that provides H3 hexagonal grid operations for the territory system.
/// Wraps low-level coordinate→H3 conversions with higher-level map region queries.
final class H3GridService {

    // MARK: - Singleton

    static let shared = H3GridService()
    private init() {}

    // MARK: - Resolution

    let defaultResolution = AppConstants.Location.h3Resolution

    // MARK: - Index Operations

    /// Returns the H3 index for a given coordinate.
    func h3Index(for coordinate: CLLocationCoordinate2D, resolution: Int? = nil) -> String {
        coordinate.h3Index(resolution: resolution ?? defaultResolution)
    }

    /// Returns the H3 index for a CLLocation.
    func h3Index(for location: CLLocation, resolution: Int? = nil) -> String {
        h3Index(for: location.coordinate, resolution: resolution)
    }

    // MARK: - Boundary & Center

    /// Returns the 6 corner coordinates of the hex cell at the given index.
    func hexBoundary(for coordinate: CLLocationCoordinate2D, resolution: Int? = nil) -> [CLLocationCoordinate2D] {
        coordinate.h3HexBoundary(resolution: resolution ?? defaultResolution)
    }

    /// Returns the center coordinate of the hex cell.
    func cellCenter(for coordinate: CLLocationCoordinate2D, resolution: Int? = nil) -> CLLocationCoordinate2D {
        coordinate.h3CellCenter(resolution: resolution ?? defaultResolution)
    }

    // MARK: - Neighbors

    /// Returns the 6 neighboring cell indices.
    func neighbors(for coordinate: CLLocationCoordinate2D, resolution: Int? = nil) -> [String] {
        coordinate.h3Neighbors(resolution: resolution ?? defaultResolution)
    }

    /// Returns the neighboring cell indices for a given H3 index string.
    func neighbors(forIndex index: String) -> [String] {
        guard let coordinate = coordinate(fromIndex: index) else { return [] }
        return coordinate.h3Neighbors(resolution: resolution(fromIndex: index))
    }

    // MARK: - Visible Region Cells

    /// Returns all H3 cell indices that fall within the given map region.
    /// Used to determine which territories to fetch from the database.
    func cellIndices(in region: MKCoordinateRegion, resolution: Int? = nil) -> [String] {
        let res = resolution ?? defaultResolution
        let factor = h3Factor(for: res)

        let minLat = region.center.latitude - region.span.latitudeDelta / 2.0
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2.0
        let minLon = region.center.longitude - region.span.longitudeDelta / 2.0
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2.0

        let startLat = Int(floor(minLat * factor))
        let endLat = Int(floor(maxLat * factor))
        let startLon = Int(floor(minLon * factor))
        let endLon = Int(floor(maxLon * factor))

        var indices: [String] = []
        indices.reserveCapacity((endLat - startLat + 1) * (endLon - startLon + 1))

        for qLat in startLat...endLat {
            for qLon in startLon...endLon {
                indices.append("\(res)_\(qLat)_\(qLon)")
            }
        }

        return indices
    }

    /// Returns the approximate number of cells visible in a map region.
    /// Useful for deciding whether to render overlays (skip if too many).
    func estimatedCellCount(in region: MKCoordinateRegion, resolution: Int? = nil) -> Int {
        let res = resolution ?? defaultResolution
        let factor = h3Factor(for: res)

        let latCells = Int(ceil(region.span.latitudeDelta * factor)) + 1
        let lonCells = Int(ceil(region.span.longitudeDelta * factor)) + 1

        return latCells * lonCells
    }

    // MARK: - MKPolygon Generation

    /// Creates an MKPolygon overlay for the hex cell at the given coordinate.
    func hexPolygon(for coordinate: CLLocationCoordinate2D, resolution: Int? = nil) -> MKPolygon {
        let boundary = hexBoundary(for: coordinate, resolution: resolution)
        return MKPolygon(coordinates: boundary, count: boundary.count)
    }

    /// Creates an MKPolygon overlay for a given H3 index string.
    func hexPolygon(forIndex index: String) -> MKPolygon? {
        guard let coordinate = coordinate(fromIndex: index) else { return nil }
        let res = resolution(fromIndex: index)
        let polygon = hexPolygon(for: coordinate, resolution: res)
        polygon.title = index
        return polygon
    }

    // MARK: - Index Parsing

    /// Extracts the approximate center coordinate from an H3 index string.
    /// Index format: "resolution_quantizedLat_quantizedLon"
    func coordinate(fromIndex index: String) -> CLLocationCoordinate2D? {
        let parts = index.split(separator: "_")
        guard parts.count == 3,
              let res = Int(parts[0]),
              let qLat = Int(parts[1]),
              let qLon = Int(parts[2]) else {
            return nil
        }

        let factor = h3Factor(for: res)
        let lat = (Double(qLat) + 0.5) / factor
        let lon = (Double(qLon) + 0.5) / factor

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Extracts the resolution from an H3 index string.
    func resolution(fromIndex index: String) -> Int {
        let parts = index.split(separator: "_")
        guard let first = parts.first, let res = Int(first) else {
            return defaultResolution
        }
        return res
    }

    // MARK: - Route Coverage

    /// Returns unique H3 cell indices that a route passes through.
    /// Used for calculating territory captures during a run.
    func coveredCells(along route: [CLLocationCoordinate2D], resolution: Int? = nil) -> Set<String> {
        let res = resolution ?? defaultResolution
        var cells = Set<String>()
        for coordinate in route {
            cells.insert(coordinate.h3Index(resolution: res))
        }
        return cells
    }

    /// Returns unique H3 cell indices from a list of RoutePoints.
    func coveredCells(along routePoints: [RoutePoint], resolution: Int? = nil) -> Set<String> {
        coveredCells(along: routePoints.map(\.coordinate), resolution: resolution)
    }

    // MARK: - Distance

    /// Returns the distance in meters between two H3 cell centers.
    func distanceBetweenCells(index1: String, index2: String) -> CLLocationDistance? {
        guard let coord1 = coordinate(fromIndex: index1),
              let coord2 = coordinate(fromIndex: index2) else {
            return nil
        }
        return coord1.distance(to: coord2)
    }

    // MARK: - Private Helpers

    /// Factor for quantizing coordinates — must match CLLocationCoordinate2D+H3.
    private func h3Factor(for resolution: Int) -> Double {
        switch resolution {
        case 7:  return 145.0
        case 8:  return 290.0
        case 9:  return 580.0
        case 10: return 1160.0
        case 11: return 2320.0
        default: return 580.0
        }
    }
}
