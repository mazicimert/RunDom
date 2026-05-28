import SwiftUI
import AuthenticationServices

/// Pre-deletion gate. The user must re-authenticate with Apple so we can:
///   1) capture a fresh authorizationCode for server-side token revocation
///   2) satisfy Firebase's "requires recent login" rule for account deletion
struct DeleteAccountReauthSheet: View {
    let authService: AuthService
    let onSucceeded: () async -> Bool
    let onFinished: (_ success: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var isReauthenticating = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                warningCard
                infoBullets

                Spacer(minLength: 12)

                if isDeleting {
                    deletingState
                } else {
                    appleButton
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)
            .padding(.vertical, 20)
            .background(Color.surfacePrimary.ignoresSafeArea())
            .navigationTitle("settings.deleteAccount.reauth.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel".localized) {
                        onFinished(false)
                        dismiss()
                    }
                    .disabled(isReauthenticating || isDeleting)
                }
            }
            .interactiveDismissDisabled(isReauthenticating || isDeleting)
        }
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 6) {
                Text("settings.deleteAccount.reauth.warning.title".localized)
                    .font(.headline)
                Text("settings.deleteAccount.reauth.warning.body".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private var infoBullets: some View {
        VStack(alignment: .leading, spacing: 10) {
            bulletRow("settings.deleteAccount.reauth.bullet1".localized)
            bulletRow("settings.deleteAccount.reauth.bullet2".localized)
            bulletRow("settings.deleteAccount.reauth.bullet3".localized)
        }
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "trash.circle.fill")
                .foregroundStyle(.red.opacity(0.8))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            let hashedNonce = authService.prepareAppleSignIn().hashedNonce
            request.requestedScopes = []
            request.nonce = hashedNonce
        } onCompletion: { result in
            Task { await handleAppleResult(result) }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous))
        .disabled(isReauthenticating)
    }

    private var deletingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("settings.deleteAccount.deleting".localized)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    @MainActor
    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            // User cancelled is a normal outcome — don't surface an error.
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            AppLogger.auth.error("Apple re-auth failed: \(error.localizedDescription)")
            errorMessage = "settings.deleteAccount.reauth.failed".localized

        case .success(let authorization):
            isReauthenticating = true
            errorMessage = nil

            do {
                try await authService.reauthenticateWithApple(authorization: authorization)
            } catch {
                AppLogger.auth.error("Apple re-auth call failed: \(error.localizedDescription)")
                errorMessage = "settings.deleteAccount.reauth.failed".localized
                isReauthenticating = false
                return
            }

            isReauthenticating = false
            isDeleting = true
            let succeeded = await onSucceeded()
            isDeleting = false

            if succeeded {
                onFinished(true)
                dismiss()
            } else {
                errorMessage = "settings.deleteAccount.failed".localized
            }
        }
    }
}
