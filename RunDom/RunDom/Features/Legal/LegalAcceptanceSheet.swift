import SwiftUI

struct LegalAcceptanceSheet: View {
    let onAccepted: () -> Void

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isAgreed = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let firestoreService = FirestoreService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerCard
                    documentLinks
                    agreementCheckbox

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.vertical, 20)
            }
            .background(Color.surfacePrimary.ignoresSafeArea())
            .navigationTitle("legal.acceptance.title".localized)
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
                        Task { await accept() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("legal.acceptance.continue".localized)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isAgreed || isSubmitting)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text("legal.acceptance.heading".localized)
                    .font(.headline)
            }
            Text("legal.acceptance.body".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardBackground)
        )
    }

    private var documentLinks: some View {
        VStack(spacing: 10) {
            documentLinkRow(.communityGuidelines)
            documentLinkRow(.termsOfUse)
        }
    }

    private func documentLinkRow(_ doc: LegalDocument) -> some View {
        NavigationLink {
            LegalDocumentView(document: doc)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: doc == .communityGuidelines ? "person.3.fill" : "doc.text.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 28)

                Text(doc.titleLocalizationKey.localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private var agreementCheckbox: some View {
        Button {
            isAgreed.toggle()
            Haptics.impact(.light)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isAgreed ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isAgreed ? Color.accentColor : .secondary)
                Text("legal.acceptance.checkbox".localized)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }

    private func accept() async {
        guard isAgreed, var user = appState.currentUser else { return }
        isSubmitting = true
        errorMessage = nil

        let now = Date()
        let version = LegalDocument.currentTermsVersion

        do {
            user.acceptedCommunityGuidelinesAt = now
            user.acceptedTermsVersion = version
            try await firestoreService.updateUser(user)
            appState.currentUser = user

            UserDefaults.standard.set(now, forKey: AppConstants.UserDefaultsKeys.acceptedCommunityGuidelinesAt)
            UserDefaults.standard.set(version, forKey: AppConstants.UserDefaultsKeys.acceptedTermsVersion)

            Haptics.notification(.success)
            onAccepted()
            dismiss()
        } catch {
            AppLogger.firebase.error("Failed to persist legal acceptance: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
            isSubmitting = false
        }
    }
}
