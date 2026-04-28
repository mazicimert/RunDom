import SwiftUI
import UIKit

struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState

    private var welcomeTitle: String {
        guard let displayName = resolvedDisplayName, !displayName.isEmpty else {
            return "welcome.title.generic".localized
        }

        return "welcome.title.named".localized(with: displayName)
    }

    private var resolvedDisplayName: String? {
        guard let rawName = appState.currentUser?.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawName.isEmpty else {
            return nil
        }

        let ignoredNames = [
            "runner.defaultName".localized,
            "Runner",
            "Koşucu"
        ]

        return ignoredNames.contains(rawName) ? nil : rawName
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.02, green: 0.06, blue: 0.12),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(y: -120)

            VStack(spacing: 28) {
                Spacer(minLength: 20)

                characterSection

                VStack(spacing: 14) {
                    Text(welcomeTitle)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("welcome.subtitle".localized)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: AppConstants.Animation.standard)) {
                        appState.dismissWelcome()
                    }
                } label: {
                    Text("welcome.cta".localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
    }

    private var characterSection: some View {
        Group {
            if UIImage(named: "welcome_character") != nil {
                Image("welcome_character")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 340)
                    .shadow(color: Color.black.opacity(0.24), radius: 30, y: 18)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 40, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    VStack(spacing: 18) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 92, weight: .semibold))
                            .foregroundStyle(Color.accentColor)

                        Text("welcome.character.placeholder".localized)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                }
                .frame(maxWidth: 340)
                .frame(height: 400)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppState())
}
