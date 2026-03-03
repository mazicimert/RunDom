import Foundation
import CoreLocation

struct Dropzone: Codable, Identifiable, Equatable {
    let id: String
    let h3Index: String
    let latitude: Double
    let longitude: Double
    let activationDate: Date
    let expirationDate: Date
    var claimedBy: [String] = []
    let seasonId: String
    var hintShownDate: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isActive: Bool {
        let now = Date()
        return now >= activationDate && now < expirationDate
    }

    var isHintVisible: Bool {
        guard let hintDate = hintShownDate else { return false }
        return Date() >= hintDate && !isActive
    }

    var isExpired: Bool {
        Date() >= expirationDate
    }

    var isFullyClaimed: Bool {
        claimedBy.count >= AppConstants.Game.dropzoneMaxClaimants
    }

    func canClaim(userId: String) -> Bool {
        isActive && !isFullyClaimed && !claimedBy.contains(userId)
    }
}
