import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onComplete: () -> Void

    @State private var isAnimating = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @FocusState private var focusedField: EmailField?

    private enum EmailField {
        case firstName, lastName, email, password, confirmPassword
    }

    var body: some View {
        ZStack {
            authBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection

                    if viewModel.showEmailAuth {
                        emailAuthSection
                    } else {
                        socialSignInSection
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Background

    private var authBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.96),
                    Color.accentColor.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: 100, y: -220)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 94, height: 94)

                Image(systemName: "figure.run")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 8) {
                Text("Runpire")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .padding(.top, 8)
        .scaleEffect(isAnimating ? 1.0 : 0.92)
        .opacity(isAnimating ? 1.0 : 0)
    }

    private var headerSubtitle: String {
        if !viewModel.showEmailAuth {
            return "auth.hero.subtitle".localized
        }

        return viewModel.isSignUpMode
            ? "auth.form.signup.subtitle".localized
            : "auth.form.signin.subtitle".localized
    }

    // MARK: - Social Sign In

    private var socialSignInSection: some View {
        VStack(spacing: 18) {
            authPanel {
                VStack(alignment: .leading, spacing: 18) {
                    Text("auth.hero.title".localized)
                        .font(.title3.bold())

                    Text("auth.hero.body".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        SignInWithAppleButton(.signIn) { request in
                            let hashedNonce = viewModel.prepareAppleSignIn()
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = hashedNonce
                        } onCompletion: { result in
                            viewModel.handleAppleSignIn(result: result)
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous))

                        Button {
                            viewModel.signInWithGoogle()
                        } label: {
                            HStack(spacing: 10) {
                                Image("google_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)

                                Text("auth.signInGoogle".localized)
                                    .font(.headline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        }
                        .buttonStyle(AuthSecondaryActionStyle())
                    }

                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)

                        Text("auth.divider".localized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.showEmailAuthForm()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                            Text("auth.signInEmail".localized)
                        }
                    }
                    .buttonStyle(AuthGhostActionStyle())

                    if let errorMessage = viewModel.errorMessage {
                        authNotice(message: errorMessage, tone: .error)
                    }
                }
            }
        }
        .disabled(viewModel.isSigningIn)
        .opacity(viewModel.isSigningIn ? 0.6 : 1.0)
    }

    // MARK: - Email Auth

    private var emailAuthSection: some View {
        authPanel {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.isSignUpMode ? "auth.form.signup.title".localized : "auth.form.signin.title".localized)
                        .font(.title3.bold())

                    Text(viewModel.isSignUpMode ? "auth.form.signup.body".localized : "auth.form.signin.body".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    authNotice(message: errorMessage, tone: .error)
                }

                if viewModel.passwordResetSent {
                    authNotice(message: "auth.email.resetSent".localized, tone: .success)
                }

                VStack(spacing: 16) {
                    if viewModel.isSignUpMode {
                        labeledField(
                            title: "auth.email.firstName".localized,
                            error: viewModel.error(for: .firstName)
                        ) {
                            TextField("", text: $viewModel.firstName)
                                .textContentType(.givenName)
                                .focused($focusedField, equals: .firstName)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .lastName }
                        }

                        labeledField(
                            title: "auth.email.lastName".localized,
                            error: nil
                        ) {
                            TextField("", text: $viewModel.lastName)
                                .textContentType(.familyName)
                                .focused($focusedField, equals: .lastName)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .email }
                        }
                    }

                    labeledField(
                        title: "auth.field.email".localized,
                        error: viewModel.error(for: .email)
                    ) {
                        TextField("", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }

                    labeledField(
                        title: "auth.field.password".localized,
                        error: viewModel.error(for: .password),
                        helper: viewModel.isSignUpMode ? "auth.email.passwordHint".localized : nil
                    ) {
                        HStack(spacing: 12) {
                            Group {
                                if showPassword {
                                    TextField("", text: $viewModel.password)
                                } else {
                                    SecureField("", text: $viewModel.password)
                                }
                            }
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

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 28, height: 28)
                            }
                            .accessibilityLabel(showPassword ? "auth.password.hide".localized : "auth.password.show".localized)
                        }
                    }

                    if viewModel.isSignUpMode {
                        labeledField(
                            title: "auth.field.confirmPassword".localized,
                            error: viewModel.error(for: .confirmPassword)
                        ) {
                            HStack(spacing: 12) {
                                Group {
                                    if showConfirmPassword {
                                        TextField("", text: $viewModel.confirmPassword)
                                    } else {
                                        SecureField("", text: $viewModel.confirmPassword)
                                    }
                                }
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .confirmPassword)
                                .submitLabel(.go)
                                .onSubmit { viewModel.signInWithEmail() }

                                Button {
                                    showConfirmPassword.toggle()
                                } label: {
                                    Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 28, height: 28)
                                }
                                .accessibilityLabel(showConfirmPassword ? "auth.password.hide".localized : "auth.password.show".localized)
                            }
                        }
                    }
                }

                if !viewModel.isSignUpMode {
                    Button("auth.email.forgotPassword".localized) {
                        viewModel.sendPasswordReset()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Button {
                    viewModel.signInWithEmail()
                } label: {
                    HStack {
                        if viewModel.isSigningIn {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(viewModel.isSignUpMode ? "auth.email.signUp".localized : "auth.email.signIn".localized)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                VStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.toggleAuthMode()
                        }
                    } label: {
                        Text(viewModel.isSignUpMode ? "auth.email.hasAccount".localized : "auth.email.noAccount".localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.hideEmailAuthForm()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.caption.weight(.bold))
                            Text("auth.email.otherMethods".localized)
                                .font(.subheadline)
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .disabled(viewModel.isSigningIn)
        .opacity(viewModel.isSigningIn ? 0.7 : 1.0)
    }

    // MARK: - Building Blocks

    private func authPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func authNotice(message: String, tone: AuthNoticeTone) -> some View {
        HStack(spacing: 10) {
            Image(systemName: tone.icon)
                .foregroundStyle(tone.color)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(tone.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tone.color.opacity(0.22), lineWidth: 1)
        )
    }

    private func labeledField<Content: View>(
        title: String,
        error: String?,
        helper: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            authInputContainer(hasError: error != nil) {
                content()
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let helper {
                Text(helper)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func authInputContainer<Content: View>(
        hasError: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            content()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                .stroke(hasError ? Color.red.opacity(0.45) : Color.white.opacity(0.10), lineWidth: 1)
        )
    }

}

private enum AuthNoticeTone {
    case error
    case success

    var color: Color {
        switch self {
        case .error:
            return .red
        case .success:
            return .green
        }
    }

    var icon: String {
        switch self {
        case .error:
            return "exclamationmark.triangle.fill"
        case .success:
            return "checkmark.circle.fill"
        }
    }
}

private struct AuthSecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: AppConstants.Animation.quick), value: configuration.isPressed)
    }
}

private struct AuthGhostActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.28), lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: AppConstants.Animation.quick), value: configuration.isPressed)
    }
}

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
