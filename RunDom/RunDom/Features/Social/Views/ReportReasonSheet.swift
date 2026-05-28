import SwiftUI

struct ReportReasonSheet: View {
    let targetType: ReportTargetType
    let targetId: String
    let postId: String?
    let onSubmitted: () -> Void

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: ReportReason?
    @State private var note: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let reportService = ReportService()
    private let maxNoteLength = 300

    private var title: String {
        switch targetType {
        case .post:    return "report.title.post".localized
        case .comment: return "report.title.comment".localized
        case .user:    return "report.title.user".localized
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("report.prompt".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    reasonList

                    if selectedReason == .other {
                        noteField
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.vertical, 16)
            }
            .background(Color.surfacePrimary.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        submit()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("report.submit".localized)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(selectedReason == nil || isSubmitting)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var reasonList: some View {
        VStack(spacing: 8) {
            ForEach(ReportReason.allCases) { reason in
                reasonRow(reason)
            }
        }
    }

    private func reasonRow(_ reason: ReportReason) -> some View {
        let isSelected = selectedReason == reason
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedReason = reason
            }
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                Text(reason.localizationKey.localized)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("report.note.hint".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                "report.note.placeholder".localized,
                text: $note,
                axis: .vertical
            )
            .lineLimit(3...6)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.cardBackground)
            )
            .onChange(of: note) { _, newValue in
                if newValue.count > maxNoteLength {
                    note = String(newValue.prefix(maxNoteLength))
                }
            }

            HStack {
                Spacer()
                Text("\(note.count)/\(maxNoteLength)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func submit() {
        guard let reporterId = appState.currentUser?.id,
              let reason = selectedReason else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await reportService.submitReportChecked(
                    reporterId: reporterId,
                    targetType: targetType,
                    targetId: targetId,
                    postId: postId,
                    reason: reason,
                    note: reason == .other ? note : nil
                )
                Haptics.notification(.success)
                onSubmitted()
                dismiss()
            } catch ReportError.alreadyReported {
                errorMessage = "report.error.duplicate".localized
                isSubmitting = false
            } catch {
                AppLogger.firebase.error("Report submit failed: \(error.localizedDescription)")
                errorMessage = "report.error.generic".localized
                isSubmitting = false
            }
        }
    }
}
