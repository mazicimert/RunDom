import Foundation
import CoreLocation

struct RoutePoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let speed: Double
    let altitude: Double
    let horizontalAccuracy: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var speedKmh: Double {
        max(speed * 3.6, 0)
    }

    init(latitude: Double, longitude: Double, timestamp: Date, speed: Double, altitude: Double, horizontalAccuracy: Double = 0) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.speed = speed
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
    }

    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp
        self.speed = location.speed
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
    }
}
