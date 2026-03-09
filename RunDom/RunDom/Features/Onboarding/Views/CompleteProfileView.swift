import SwiftUI

struct CompleteProfileView: View {
    @EnvironmentObject private var appState: AppState

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case firstName, lastName
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Color.accentColor)

                Text("profile.complete.title".localized)
                    .font(.system(size: 28, weight: .black, design: .rounded))

                Text("profile.complete.subtitle".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            // Error banner
            if let errorMessage {
                ErrorBannerView(
                    message: errorMessage,
                    onDismiss: { self.errorMessage = nil }
                )
            }

            // Name fields
            VStack(spacing: 12) {
                TextField("auth.email.firstName".localized, text: $firstName)
                    .textFieldStyle(AuthTextFieldStyle())
                    .textContentType(.givenName)
                    .focused($focusedField, equals: .firstName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .lastName }

                TextField("auth.email.lastName".localized, text: $lastName)
                    .textFieldStyle(AuthTextFieldStyle())
                    .textContentType(.familyName)
                    .focused($focusedField, equals: .lastName)
                    .submitLabel(.done)
                    .onSubmit { saveProfile() }
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)

            // Continue button
            Button {
                saveProfile()
            } label: {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("common.continue".localized)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppConstants.UI.screenPadding)
            .disabled(isSaving)

            // Skip button
            Button {
                appState.requiresProfileCompletion = false
            } label: {
                Text("common.skip".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .disabled(isSaving)

            Spacer()
                .frame(height: 40)
        }
        .onAppear {
            focusedField = .firstName
        }
    }

    private func saveProfile() {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        guard !trimmedFirst.isEmpty else {
            errorMessage = "auth.email.fillAllFields".localized
            return
        }

        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)
        let displayName = trimmedLast.isEmpty ? trimmedFirst : "\(trimmedFirst) \(trimmedLast)"

        isSaving = true
        errorMessage = nil

        Task {
            await appState.completeProfile(displayName: displayName)
            isSaving = false
        }
    }
}

#Preview {
    CompleteProfileView()
        .environmentObject(AppState())
}
