import SwiftUI
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - State

    @Published var isSigningIn = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: - Apple Sign In

    var appleSignInNonce: String?

    func prepareAppleSignIn() -> String {
        let result = authService.prepareAppleSignIn()
        appleSignInNonce = result.nonce
        return result.hashedNonce
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            isSigningIn = true
            errorMessage = nil
            Task {
                do {
                    try await authService.signInWithApple(authorization: authorization)
                    AppLogger.auth.info("Apple Sign In completed")
                } catch {
                    errorMessage = "error.generic".localized
                    AppLogger.auth.error("Apple Sign In failed: \(error.localizedDescription)")
                }
                isSigningIn = false
            }
        case .failure(let error):
            // User cancelled — not an error
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = "error.generic".localized
            AppLogger.auth.error("Apple Sign In error: \(error.localizedDescription)")
        }
    }

    // MARK: - Google Sign In (placeholder — requires GoogleSignIn SDK setup)

    func signInWithGoogle() {
        // TODO: Implement when GoogleSignIn SDK is integrated
        AppLogger.auth.info("Google Sign In tapped — not yet implemented")
    }

    // MARK: - Error

    func dismissError() {
        withAnimation(.easeOut(duration: AppConstants.Animation.quick)) {
            errorMessage = nil
        }
    }
}
