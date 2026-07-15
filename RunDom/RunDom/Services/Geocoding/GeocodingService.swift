import Foundation
import CoreLocation

/// Converts coordinates to human-readable neighborhood/locality names
/// using Apple's CLGeocoder.
final class GeocodingService {

    struct AreaIdentity: Equatable {
        let displayName: String
        let areaId: String
    }

    // MARK: - Singleton

    static let shared = GeocodingService()

    private let geocoder = CLGeocoder()
    private var cache: [String: AreaIdentity] = [:]

    private init() {}

    // MARK: - Reverse Geocoding

    /// Returns the neighborhood or locality name for a coordinate.
    /// Results are cached in memory to reduce API calls.
    func neighborhoodName(for coordinate: CLLocationCoordinate2D) async -> String? {
        await areaIdentity(for: coordinate)?.displayName
    }

    /// Returns a display label plus a locale-independent grouping key. The key
    /// uses country/city/neighborhood placemark components and falls back to a
    /// deterministic coarse grid when geocoding lacks sufficient metadata.
    func areaIdentity(for coordinate: CLLocationCoordinate2D) async -> AreaIdentity? {
        let cacheKey = "\(String(format: "%.4f", coordinate.latitude)),\(String(format: "%.4f", coordinate.longitude))"

        if let cached = cache[cacheKey] {
            return cached
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }

            // Prefer subLocality (neighborhood), fall back to locality (city)
            guard let name = placemark.subLocality ?? placemark.locality else { return nil }
            let identity = AreaIdentity(
                displayName: name,
                areaId: stableAreaId(for: placemark, coordinate: coordinate)
            )
            cache[cacheKey] = identity

            AppLogger.notification.info("Geocoded (\(coordinate.latitude), \(coordinate.longitude)) → \(name)")
            return identity
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

    private func stableAreaId(for placemark: CLPlacemark, coordinate: CLLocationCoordinate2D) -> String {
        var components: [String] = []
        if let countryCode = placemark.isoCountryCode { components.append(countryCode) }
        if let city = placemark.locality ?? placemark.administrativeArea { components.append(city) }
        if let neighborhood = placemark.subLocality, neighborhood != placemark.locality {
            components.append(neighborhood)
        }

        let normalized = components.map(normalizedAreaComponent).filter { !$0.isEmpty }
        if !normalized.isEmpty {
            return normalized.joined(separator: "-")
        }

        let factor = 145.0
        return "geo-7-\(Int(floor(coordinate.latitude * factor)))-\(Int(floor(coordinate.longitude * factor)))"
    }

    private func normalizedAreaComponent(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let lowercase = folded.lowercased(with: Locale(identifier: "en_US_POSIX"))
        return lowercase
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}
