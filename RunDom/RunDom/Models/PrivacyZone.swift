import Foundation
import FirebaseFirestore
import CoreLocation

// Hidden zones around home/work etc. Route points falling inside any zone
// are stripped from the post's `routePreview` so followers / public viewers
// can't see where the user lives or works. The owner sees their own raw
// route untouched (the zone only affects the post snapshot, not the
// underlying RunSession.route).
struct PrivacyZone: Codable, Identifiable, Equatable, Hashable {
    let id: String
    var name: String?
    let centerLatitude: Double
    let centerLongitude: Double
    let radius: Double           // metres; clamped 100–500 client + rules
    let createdAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }

    /// Haversine distance in metres between the zone center and a point.
    /// Cheap enough to call per route point (typical 200 pts × 5 zones).
    func contains(latitude: Double, longitude: Double) -> Bool {
        let earthRadius = 6_371_000.0 // metres
        let lat1 = centerLatitude * .pi / 180
        let lat2 = latitude * .pi / 180
        let dLat = (latitude - centerLatitude) * .pi / 180
        let dLon = (longitude - centerLongitude) * .pi / 180

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2)
            * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        let distance = earthRadius * c
        return distance <= radius
    }
}

enum PrivacyZoneConstants {
    static let minRadius: Double = 100
    static let maxRadius: Double = 500
    static let defaultRadius: Double = 200
    static let maxZonesPerUser = 5
}
