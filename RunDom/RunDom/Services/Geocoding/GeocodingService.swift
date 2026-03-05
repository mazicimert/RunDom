import Foundation
import CoreLocation

/// Converts coordinates to human-readable neighborhood/locality names
/// using Apple's CLGeocoder.
final class GeocodingService {

    // MARK: - Singleton

    static let shared = GeocodingService()

    private let geocoder = CLGeocoder()
    private var cache: [String: String] = [:]

    private init() {}

    // MARK: - Reverse Geocoding

    /// Returns the neighborhood or locality name for a coordinate.
    /// Results are cached in memory to reduce API calls.
    func neighborhoodName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let cacheKey = "\(String(format: "%.4f", coordinate.latitude)),\(String(format: "%.4f", coordinate.longitude))"

        if let cached = cache[cacheKey] {
            return cached
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }

            // Prefer subLocality (neighborhood), fall back to locality (city)
            let name = placemark.subLocality ?? placemark.locality
            if let name {
                cache[cacheKey] = name
            }

            AppLogger.notification.info("Geocoded (\(coordinate.latitude), \(coordinate.longitude)) → \(name ?? "unknown")")
            return name
        } catch {
            AppLogger.notification.error("Geocoding failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Returns the full locality string (neighborhood + city) for a coordinate.
    func fullLocalityName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }

            var parts: [String] = []
            if let subLocality = placemark.subLocality {
                parts.append(subLocality)
            }
            if let locality = placemark.locality {
                parts.append(locality)
            }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        } catch {
            AppLogger.notification.error("Full geocoding failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Clears the in-memory geocoding cache.
    func clearCache() {
        cache.removeAll()
    }
}
