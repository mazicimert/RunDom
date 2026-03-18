import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: FirebaseAuth.User?
    @Published var isAuthenticated = false

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Apple Sign In

    func prepareAppleSignIn() -> (nonce: String, hashedNonce: String) {
        let nonce = randomNonceString()
        currentNonce = nonce
        return (nonce, sha256(nonce))
    }

    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8),
              let nonce = currentNonce else {
            throw AuthError.invalidCredential
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        let result = try await Auth.auth().signIn(with: credential)
        AppLogger.auth.info("Apple Sign In successful: \(result.user.uid)")
    }

    // MARK: - Google Sign In

    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )

        let result = try await Auth.auth().signIn(with: credential)
        AppLogger.auth.info("Google Sign In successful: \(result.user.uid)")
    }

    // MARK: - Email Sign In

    func signInWithEmail(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        AppLogger.auth.info("Email Sign In successful: \(result.user.uid)")
    }

    // MARK: - Email Sign Up

    func signUpWithEmail(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        AppLogger.auth.info("Email Sign Up successful: \(result.user.uid)")
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
        AppLogger.auth.info("Password reset email sent to \(email)")
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
        AppLogger.auth.info("User signed out")
    }

    // MARK: - Delete Account

    func requiresRecentSignInForAccountDeletion(maxAge: TimeInterval = 5 * 60) async throws -> Bool {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.noUser
        }

        let tokenResult = try await user.getIDTokenResult(forcingRefresh: true)
        guard let authTime = authTimestamp(from: tokenResult.claims["auth_time"]) else {
            return true
        }

        return Date().timeIntervalSince(authTime) > maxAge
    }

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.noUser
        }
        try await user.delete()
        AppLogger.auth.info("User account deleted")
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func authTimestamp(from claim: Any?) -> Date? {
        if let seconds = claim as? TimeInterval {
            return Date(timeIntervalSince1970: seconds)
        }

        if let intSeconds = claim as? Int {
            return Date(timeIntervalSince1970: TimeInterval(intSeconds))
        }

        if let stringSeconds = claim as? String,
           let seconds = TimeInterval(stringSeconds) {
            return Date(timeIntervalSince1970: seconds)
        }

        return nil
    }
}

// MARK: - AuthError

enum AuthError: LocalizedError {
    case invalidCredential
    case noUser

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "error.generic".localized
        case .noUser:
            return "error.generic".localized
        }
    }
}
