import Foundation
import FirebaseFirestore

enum PostVisibility: String, Codable {
    case followers
    case `public`
}

struct Post: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let authorId: String
    var authorDisplayName: String
    var authorPhotoURL: String?
    var authorColor: String
    let runId: String
    let createdAt: Date

    // RunSession snapshot — persists after the original run is deleted.
    let distance: Double
    let duration: TimeInterval
    let avgSpeed: Double
    let trail: Double
    let startDate: Date
    let tags: [String]
    var note: String?
    let routePreview: [GeoPoint]
    var shareCardImageURL: String?
    var photoURLs: [String]?

    var likeCount: Int = 0
    var commentCount: Int = 0
    var visibility: PostVisibility = .followers
}
