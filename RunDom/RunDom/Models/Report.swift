import Foundation

enum ReportTargetType: String, Codable {
    case post
    case comment
    case user
}

enum ReportReason: String, Codable, CaseIterable, Identifiable {
    case spam
    case inappropriate
    case harassment
    case misinformation
    case other

    var id: String { rawValue }

    var localizationKey: String {
        "report.reason.\(rawValue)"
    }
}

enum ReportStatus: String, Codable {
    case pending
    case actioned
    case dismissed
}

struct Report: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let reporterId: String
    let targetType: ReportTargetType
    let targetId: String
    let postId: String?
    let reason: ReportReason
    let note: String?
    let createdAt: Date
    let status: ReportStatus

    static func makeDocumentId(
        reporterId: String,
        targetType: ReportTargetType,
        targetId: String
    ) -> String {
        "\(reporterId)_\(targetType.rawValue)_\(targetId)"
    }
}
