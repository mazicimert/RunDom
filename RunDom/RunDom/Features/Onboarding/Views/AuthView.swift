import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onComplete: () -> Void

    @State private var isAnimating = false
    @FocusState private var focusedField: EmailField?

    private enum EmailField {
        case email, password, confirmPassword
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 16) {
                Image(systemName: "figure.run")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(Color.accentColor)

                Text("RunDom")
                    .font(.system(size: 36, weight: .black, design: .rounded))
            }
            .scaleEffect(isAnimating ? 1.0 : 0.8)
            .opacity(isAnimating ? 1.0 : 0)

            Spacer()

            // Error banner
            if let errorMessage = viewModel.errorMessage {
                ErrorBannerView(
                    message: errorMessage,
                    onDismiss: { viewModel.dismissError() }
                )
            }

            // Password reset success
            if viewModel.passwordResetSent {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("auth.email.resetSent".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
            }

            if viewModel.showEmailAuth {
                emailAuthSection
            } else {
                socialSignInSection
            }

            // Loading indicator
            if viewModel.isSigningIn {
                ProgressView()
                    .padding(.top, 8)
            }

            Spacer()
                .frame(height: 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Social Sign In

    private var socialSignInSection: some View {
        VStack(spacing: 12) {
            // Apple Sign In
            SignInWithAppleButton(.signIn) { request in
                let hashedNonce = viewModel.prepareAppleSignIn()
                request.requestedScopes = [.fullName, .email]
                request.nonce = hashedNonce
            } onCompletion: { result in
                viewModel.handleAppleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous))

            // Google Sign In
            Button {
                viewModel.signInWithGoogle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                    Text("auth.signInGoogle".localized)
                }
            }
            .buttonStyle(SecondaryButtonStyle())

            // Email Sign In
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.showEmailAuth = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.title3)
                    Text("auth.signInEmail".localized)
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, AppConstants.UI.screenPadding)
        .disabled(viewModel.isSigningIn)
        .opacity(viewModel.isSigningIn ? 0.6 : 1.0)
    }

    // MARK: - Email Auth

    private var emailAuthSection: some View {
        VStack(spacing: 16) {
            // Email field
            TextField("auth.email.placeholder".localized, text: $viewModel.email)
                .textFieldStyle(AuthTextFieldStyle())
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: .email)
                .submitLabel(viewModel.isSignUpMode ? .next : .next)
                .onSubmit { focusedField = .password }

            // Password field
            SecureField("auth.email.password".localized, text: $viewModel.password)
                .textFieldStyle(AuthTextFieldStyle())
                .textContentType(viewModel.isSignUpMode ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .submitLabel(viewModel.isSignUpMode ? .next : .go)
                .onSubmit {
                    if viewModel.isSignUpMode {
                        focusedField = .confirmPassword
                    } else {
                        viewModel.signInWithEmail()
                    }
                }

            // Confirm password (sign up only)
            if viewModel.isSignUpMode {
                SecureField("auth.email.confirmPassword".localized, text: $viewModel.confirmPassword)
                    .textFieldStyle(AuthTextFieldStyle())
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.go)
                    .onSubmit { viewModel.signInWithEmail() }
            }

            // Sign in / Sign up button
            Button {
                viewModel.signInWithEmail()
            } label: {
                Text(viewModel.isSignUpMode ? "auth.email.signUp".localized : "auth.email.signIn".localized)
            }
            .buttonStyle(PrimaryButtonStyle())

            // Forgot password (sign in only)
            if !viewModel.isSignUpMode {
                Button {
                    viewModel.sendPasswordReset()
                } label: {
                    Text("auth.email.forgotPassword".localized)
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
            }

            // Toggle sign in / sign up
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleAuthMode()
                }
            } label: {
                Text(viewModel.isSignUpMode ? "auth.email.hasAccount".localized : "auth.email.noAccount".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Back to social sign in
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.showEmailAuth = false
                    viewModel.errorMessage = nil
                    viewModel.passwordResetSent = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                    Text("auth.email.otherMethods".localized)
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, AppConstants.UI.screenPadding)
        .disabled(viewModel.isSigningIn)
        .opacity(viewModel.isSigningIn ? 0.6 : 1.0)
    }
}

// MARK: - Auth Text Field Style

struct AuthTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

#Preview {
    AuthView(
        viewModel: AuthViewModel(authService: AuthService()),
        onComplete: {}
    )
}
