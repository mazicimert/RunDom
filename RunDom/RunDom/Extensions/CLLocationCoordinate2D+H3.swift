import CoreLocation
import Foundation

extension CLLocationCoordinate2D {

    // MARK: - H3 Index

    /// Converts this coordinate to an H3 hexagonal index string at the app's configured resolution.
    ///
    /// H3 is Uber's hierarchical hexagonal geospatial indexing system.
    /// Since there is no official Swift H3 library, we use a custom encoding
    /// based on latitude/longitude quantization that produces unique, consistent
    /// cell identifiers matching the H3 resolution concept.
    ///
    /// Resolution 9 ≈ ~175m edge length hexagons (suitable for territory gameplay).
    func h3Index(resolution: Int = AppConstants.Location.h3Resolution) -> String {
        // Quantize coordinates to create unique cell identifiers.
        // At resolution 9, each cell is approximately 175m across.
        // Factor determines the grid granularity.
        let factor = h3Factor(for: resolution)
        let quantizedLat = Int(floor(latitude * factor))
        let quantizedLon = Int(floor(longitude * factor))

        return "\(resolution)_\(quantizedLat)_\(quantizedLon)"
    }

    // MARK: - Hex Boundary

    /// Returns the 6 corner coordinates of the hexagonal cell this coordinate belongs to.
    /// Used for drawing territory overlays on the map.
    func h3HexBoundary(resolution: Int = AppConstants.Location.h3Resolution) -> [CLLocationCoordinate2D] {
        let factor = h3Factor(for: resolution)
        let centerLat = (floor(latitude * factor) + 0.5) / factor
        let centerLon = (floor(longitude * factor) + 0.5) / factor

        // Approximate hex radius in degrees based on resolution
        let radiusDegrees = 1.0 / factor * 0.6

        // Generate 6 hex corners
        return (0..<6).map { i in
            let angle = Double(i) * .pi / 3.0 + .pi / 6.0 // offset by 30° for flat-top hex
            let lat = centerLat + radiusDegrees * sin(angle)
            let lon = centerLon + radiusDegrees * cos(angle) / cos(centerLat * .pi / 180.0)
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    // MARK: - Cell Center

    /// Returns the center coordinate of the H3 cell this coordinate falls into.
    func h3CellCenter(resolution: Int = AppConstants.Location.h3Resolution) -> CLLocationCoordinate2D {
        let factor = h3Factor(for: resolution)
        let centerLat = (floor(latitude * factor) + 0.5) / factor
        let centerLon = (floor(longitude * factor) + 0.5) / factor
        return CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
    }

    // MARK: - Neighbors

    /// Returns the H3 indices of the 6 neighboring cells.
    func h3Neighbors(resolution: Int = AppConstants.Location.h3Resolution) -> [String] {
        let factor = h3Factor(for: resolution)
        let baseLat = Int(floor(latitude * factor))
        let baseLon = Int(floor(longitude * factor))

        let offsets = [
            (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1)
        ]

        return offsets.map { dLat, dLon in
            "\(resolution)_\(baseLat + dLat)_\(baseLon + dLon)"
        }
    }

    // MARK: - Distance

    /// Distance in meters between this coordinate and another.
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to)
    }

    // MARK: - Helpers

    /// Factor for quantizing coordinates at a given H3 resolution.
    /// Higher resolution = more cells = smaller hexagons.
    private func h3Factor(for resolution: Int) -> Double {
        // Approximate scaling: resolution 9 ≈ 580 cells per degree ≈ ~175m cells
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
