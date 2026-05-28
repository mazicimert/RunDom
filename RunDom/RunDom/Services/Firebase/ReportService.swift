import Foundation
import FirebaseFirestore

final class ReportService {

    private let db = Firestore.firestore()

    private var reportsCollection: CollectionReference {
        db.collection("reports")
    }

    // Composite ID ("{reporterId}_{targetType}_{targetId}") provides
    // natural dedup — a second submission for the same target fails
    // with `alreadyExists` so callers can surface a clear message.
    func submitReport(
        reporterId: String,
        targetType: ReportTargetType,
        targetId: String,
        postId: String?,
        reason: ReportReason,
        note: String?
    ) async throws {
        let id = Report.makeDocumentId(
            reporterId: reporterId,
            targetType: targetType,
            targetId: targetId
        )

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedNote = (trimmedNote?.isEmpty == false) ? trimmedNote : nil

        let report = Report(
            id: id,
            reporterId: reporterId,
            targetType: targetType,
            targetId: targetId,
            postId: postId,
            reason: reason,
            note: resolvedNote,
            createdAt: Date(),
            status: .pending
        )

        do {
            try reportsCollection
                .document(id)
                .setData(from: report)
            AppLogger.firebase.info("Report submitted: \(id) reason: \(reason.rawValue)")
        } catch {
            AppLogger.firebase.error("Report submit failed: \(error.localizedDescription)")
            throw error
        }
    }

    // Tries a write but treats "already reported" as a typed error so the
    // UI can show "you already reported this" instead of a generic failure.
    func submitReportChecked(
        reporterId: String,
        targetType: ReportTargetType,
        targetId: String,
        postId: String?,
        reason: ReportReason,
        note: String?
    ) async throws {
        let id = Report.makeDocumentId(
            reporterId: reporterId,
            targetType: targetType,
            targetId: targetId
        )

        // Fast path: if a doc already exists, surface duplicate without a
        // failed setData round-trip (rules forbid update; setData would error).
        let existing = try await reportsCollection.document(id).getDocument()
        if existing.exists {
            throw ReportError.alreadyReported
        }

        try await submitReport(
            reporterId: reporterId,
            targetType: targetType,
            targetId: targetId,
            postId: postId,
            reason: reason,
            note: note
        )
    }
}

enum ReportError: LocalizedError {
    case alreadyReported

    var errorDescription: String? {
        switch self {
        case .alreadyReported:
            return "report.error.duplicate".localized
        }
    }
}
