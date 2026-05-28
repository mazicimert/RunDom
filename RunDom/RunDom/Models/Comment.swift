import Foundation

struct Comment: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let authorId: String
    var authorDisplayName: String
    var authorPhotoURL: String?
    let text: String
    let createdAt: Date
}
