import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {

    enum AuthField {
        case firstName
        case email
        case password
        case confirmPassword
    }

    // MARK: - State

    @Published var isSigningIn = false
    @Published var errorMessage: String?
    @Published var showEmailAuth = false
    @Published var isSignUpMode = false
    @Published var email = "" {
        didSet {
            emailError = nil
            passwordResetSent = false
            errorMessage = nil
        }
    }
    @Published var password = "" {
        didSet {
            passwordError = nil
            errorMessage = nil
        }
    }
    @Published var confirmPassword = "" {
        didSet {
            confirmPasswordError = nil
        }
    }
    @Published var passwordResetSent = false
    @Published var firstName = "" {
        didSet {
            firstNameError = nil
        }
    }
    @Published var lastName = ""
    @Published var firstNameError: String?
    @Published var emailError: String?
    @Published var passwordError: String?
    @Published var confirmPasswordError: String?

    // MARK: - Dependencies

    private let authService: AuthService
    private weak var appState: AppState?

    init(authService: AuthService, appState: AppState? = nil) {
        self.authService = authService
        self.appState = appState
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
                    applySocialAuthError(error, fallbackKey: "auth.social.appleFailed")
                    AppLogger.auth.error("Apple Sign In failed: \(error.localizedDescription)")
                }
                isSigningIn = false
            }
        case .failure(let error):
            // User cancelled — not an error
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            applySocialAuthError(error, fallbackKey: "auth.social.appleFailed")
            AppLogger.auth.error("Apple Sign In error: \(error.localizedDescription)")
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?
                .rootViewController
        else {
            return
        }

        isSigningIn = true
        errorMessage = nil

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) {
            [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.isSigningIn = false
                if (error as NSError).code == GIDSignInError.canceled.rawValue {
                    return
                }
                self.applySocialAuthError(error, fallbackKey: "auth.social.googleFailed")
                AppLogger.auth.error("Google Sign In error: \(error.localizedDescription)")
                return
            }

            guard let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                self.isSigningIn = false
                self.errorMessage = "auth.social.googleFailed".localized
                return
            }

            let accessToken = user.accessToken.tokenString

            Task {
                do {
                    try await self.authService.signInWithGoogle(
                        idToken: idToken, accessToken: accessToken)
                    AppLogger.auth.info("Google Sign In completed")
                } catch {
                    self.applySocialAuthError(error, fallbackKey: "auth.social.googleFailed")
                    AppLogger.auth.error(
                        "Firebase Auth via Google failed: \(error.localizedDescription)")
                }
                self.isSigningIn = false
            }
        }
    }

    private func applySocialAuthError(_ error: Error, fallbackKey: String) {
        let nsError = error as NSError
        if isNetworkError(nsError) {
            errorMessage = "auth.error.network".localized
            return
        }
        if nsError.code == AuthErrorCode.tooManyRequests.rawValue {
            errorMessage = "auth.error.tooManyAttempts".localized
            return
        }
        if nsError.code == AuthErrorCode.userDisabled.rawValue {
            errorMessage = "auth.error.userDisabled".localized
            return
        }
        errorMessage = fallbackKey.localized
    }

    // MARK: - Email Sign In

    func signInWithEmail() {
        guard validateEmailFields() else { return }

        isSigningIn = true
        errorMessage = nil

        Task {
            do {
                if isSignUpMode {
                    try await authService.signUpWithEmail(email: email, password: password)

                    // Email sign-up already collects the user's name. Persist it immediately
                    // so the app doesn't ask for the same info again in CompleteProfile.
                    let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
                    let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)
                    let fullName = trimmedLast.isEmpty ? trimmedFirst : "\(trimmedFirst) \(trimmedLast)"

                    let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
                    changeRequest?.displayName = fullName
                    try await changeRequest?.commitChanges()

                    // Reload first to ensure a user document exists, then sync the collected
                    // name into Firestore/current session state.
                    await appState?.loadCurrentUser()
                    await appState?.completeProfile(displayName: fullName)
                    AppLogger.auth.info("Email Sign Up completed")
                } else {
                    try await authService.signInWithEmail(email: email, password: password)
                    AppLogger.auth.info("Email Sign In completed")
                }
            } catch {
                applyEmailAuthError(error, context: isSignUpMode ? .signUp : .signIn)
                AppLogger.auth.error("Email auth failed: \(error.localizedDescription)")
            }
            isSigningIn = false
        }
    }

    func sendPasswordReset() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            emailError = "auth.email.enterEmail".localized
            return
        }

        guard isValidEmail(trimmedEmail) else {
            emailError = "auth.email.invalidEmail".localized
            return
        }

        isSigningIn = true
        errorMessage = nil
        passwordResetSent = false

        Task {
            do {
                try await authService.sendPasswordReset(email: trimmedEmail)
                passwordResetSent = true
            } catch {
                applyEmailAuthError(error, context: .passwordReset)
                AppLogger.auth.error("Password reset failed: \(error.localizedDescription)")
            }
            isSigningIn = false
        }
    }

    func toggleAuthMode() {
        isSignUpMode.toggle()
        resetEmailAuthState(keepEmail: true)
    }

    func showEmailAuthForm() {
        showEmailAuth = true
        clearMessages()
    }

    func hideEmailAuthForm() {
        showEmailAuth = false
        clearMessages()
    }

    func error(for field: AuthField) -> String? {
        switch field {
        case .firstName:
            return firstNameError
        case .email:
            return emailError
        case .password:
            return passwordError
        case .confirmPassword:
            return confirmPasswordError
        }
    }

    private func validateEmailFields() -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        resetFieldErrors()

        if isSignUpMode {
            guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty else {
                firstNameError = "auth.email.firstName.required".localized
                return false
            }
        }

        guard !trimmedEmail.isEmpty else {
            emailError = "auth.email.enterEmail".localized
            return false
        }

        guard !password.isEmpty else {
            passwordError = "auth.email.fillAllFields".localized
            return false
        }

        guard isValidEmail(trimmedEmail) else {
            emailError = "auth.email.invalidEmail".localized
            return false
        }

        guard password.count >= 6 else {
            passwordError = "auth.email.passwordTooShort".localized
            return false
        }

        if isSignUpMode {
            guard password == confirmPassword else {
                confirmPasswordError = "auth.email.passwordMismatch".localized
                return false
            }
        }

        return true
    }

    private enum EmailAuthContext {
        case signIn
        case signUp
        case passwordReset

        var fallbackKey: String {
            switch self {
            case .signIn: return "auth.email.signInFailed"
            case .signUp: return "auth.email.signUpFailed"
            case .passwordReset: return "auth.email.resetFailed"
            }
        }
    }

    private func applyEmailAuthError(_ error: Error, context: EmailAuthContext) {
        let nsError = error as NSError

        // Network failure surfaces as NSURLErrorDomain even when wrapped by Firebase.
        if isNetworkError(nsError) {
            errorMessage = "auth.error.network".localized
            return
        }

        switch nsError.code {
        case AuthErrorCode.invalidEmail.rawValue:
            emailError = "auth.email.invalidEmail".localized
        case AuthErrorCode.userNotFound.rawValue:
            emailError = "auth.email.userNotFound".localized
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            emailError = "auth.email.alreadyInUse".localized
        case AuthErrorCode.wrongPassword.rawValue:
            passwordError = "auth.email.wrongPassword".localized
        case AuthErrorCode.weakPassword.rawValue:
            passwordError = "auth.email.passwordTooShort".localized
        case AuthErrorCode.invalidCredential.rawValue:
            // With Firebase email-enumeration protection enabled, both wrong email
            // and wrong password collapse into this single code — show a banner so
            // we don't blame the wrong field.
            errorMessage = "auth.email.invalidCredentials".localized
        case AuthErrorCode.tooManyRequests.rawValue:
            errorMessage = "auth.error.tooManyAttempts".localized
        case AuthErrorCode.userDisabled.rawValue:
            errorMessage = "auth.error.userDisabled".localized
        case AuthErrorCode.networkError.rawValue:
            errorMessage = "auth.error.network".localized
        default:
            errorMessage = context.fallbackKey.localized
        }
    }

    private func isNetworkError(_ error: NSError) -> Bool {
        if error.code == AuthErrorCode.networkError.rawValue { return true }
        if error.domain == NSURLErrorDomain { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSURLErrorDomain {
            return true
        }
        return false
    }

    private func isValidEmail(_ email: String) -> Bool {
        email.contains("@") && email.contains(".")
    }

    private func resetFieldErrors() {
        firstNameError = nil
        emailError = nil
        passwordError = nil
        confirmPasswordError = nil
    }

    private func clearMessages() {
        errorMessage = nil
        passwordResetSent = false
        resetFieldErrors()
    }

    private func resetEmailAuthState(keepEmail: Bool) {
        clearMessages()
        password = ""
        confirmPassword = ""
        firstName = ""
        lastName = ""

        if !keepEmail {
            email = ""
        }
    }

    // MARK: - Error

    func dismissError() {
        withAnimation(.easeOut(duration: AppConstants.Animation.quick)) {
            errorMessage = nil
        }
    }
}
