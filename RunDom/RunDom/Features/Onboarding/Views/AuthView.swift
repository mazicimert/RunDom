import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onComplete: () -> Void

    @State private var isAnimating = false

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

            // Sign-in buttons
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

                // Google Sign In (optional)
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
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)
            .disabled(viewModel.isSigningIn)
            .opacity(viewModel.isSigningIn ? 0.6 : 1.0)

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
}

#Preview {
    AuthView(
        viewModel: AuthViewModel(authService: AuthService()),
        onComplete: {}
    )
}
