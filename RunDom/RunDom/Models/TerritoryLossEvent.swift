import Foundation

struct TerritoryLossEvent: Codable, Identifiable, Equatable {
    let id: String
    let seasonId: String
    let h3Index: String
    let capturedAt: Date
    let capturedByUserId: String
    let capturerDisplayName: String?
    var isSeen: Bool
    var seenAt: Date?
}
