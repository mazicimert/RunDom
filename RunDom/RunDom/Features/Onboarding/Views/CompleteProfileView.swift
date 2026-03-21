import SwiftUI

struct CompleteProfileView: View {
    @EnvironmentObject private var appState: AppState

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isAnimating = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case firstName
        case lastName
    }

    var body: some View {
        ZStack {
            profileBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection

                    profilePanel {
                        VStack(alignment: .leading, spacing: 22) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("profile.complete.title".localized)
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)

                                Text("profile.complete.subtitle".localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let errorMessage {
                                profileNotice(message: errorMessage)
                            }

                            VStack(spacing: 16) {
                                profileField(title: "auth.email.firstName".localized) {
                                    TextField("", text: $firstName)
                                        .textContentType(.givenName)
                                        .focused($focusedField, equals: .firstName)
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .lastName }
                                }

                                profileField(title: "auth.email.lastName".localized) {
                                    TextField("", text: $lastName)
                                        .textContentType(.familyName)
                                        .focused($focusedField, equals: .lastName)
                                        .submitLabel(.done)
                                        .onSubmit { saveProfile() }
                                }
                            }

                            Button {
                                saveProfile()
                            } label: {
                                HStack {
                                    if isSaving {
                                        ProgressView()
                                            .tint(.white)
                                    }

                                    Text("common.continue".localized)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isSaving)

                            Button {
                                appState.requiresProfileCompletion = false
                            } label: {
                                Text("common.skip".localized)
                            }
                            .buttonStyle(CompleteProfileGhostActionStyle())
                            .disabled(isSaving)
                        }
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            prefillNameIfPossible()
            focusedField = .firstName

            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                isAnimating = true
            }
        }
    }

    private var profileBackground: some View {
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

    private var headerSection: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 94, height: 94)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 8) {
                Text("Runpire")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("profile.complete.subtitle".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .padding(.top, 8)
        .scaleEffect(isAnimating ? 1.0 : 0.92)
        .opacity(isAnimating ? 1.0 : 0.0)
    }

    private func profilePanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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

    private func profileNotice(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.red.opacity(0.22), lineWidth: 1)
        )
    }

    private func profileField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

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
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }

    private func prefillNameIfPossible() {
        guard firstName.isEmpty, lastName.isEmpty else { return }
        guard let rawName = appState.currentUser?.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawName.isEmpty else {
            return
        }

        let ignoredNames = ["runner.defaultName".localized, "Runner", "Koşucu"]
        guard !ignoredNames.contains(rawName) else { return }

        let parts = rawName.split(separator: " ").map(String.init)
        guard let first = parts.first else { return }

        firstName = first
        if parts.count > 1 {
            lastName = parts.dropFirst().joined(separator: " ")
        }
    }

    private func saveProfile() {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        guard !trimmedFirst.isEmpty else {
            errorMessage = "auth.email.firstName.required".localized
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

private struct CompleteProfileGhostActionStyle: ButtonStyle {
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

#Preview {
    CompleteProfileView()
        .environmentObject(AppState())
}
