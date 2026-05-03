import Foundation
import SwiftUI

struct FirstMissionView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter

    @State private var hexPulse = false
    @State private var contentVisible = false

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                heroVisual
                    .frame(height: 280)

                Spacer().frame(height: 28)

                VStack(spacing: 14) {
                    Text(greetingText)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)

                    Text("onboarding.firstMission.title".localized)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("onboarding.firstMission.subtitle".localized)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .opacity(contentVisible ? 1 : 0)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Haptics.impact(.medium)
                        AnalyticsService.logOnboardingFirstMissionAction(action: "start")
                        router.selectedTab = .run
                        appState.dismissWelcome()
                    } label: {
                        Text("onboarding.firstMission.cta.start".localized)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        AnalyticsService.logOnboardingFirstMissionAction(action: "explore")
                        appState.dismissWelcome()
                    } label: {
                        Text("onboarding.firstMission.cta.explore".localized)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.bottom, 32)
                .opacity(contentVisible ? 1 : 0)
            }
        }
        .onAppear {
            AnalyticsService.logOnboardingFirstMissionShown()
            animateIn()
        }
    }

    // MARK: - Derived

    private var userColor: Color {
        guard let hex = appState.currentUser?.color,
              let color = Color(hex: hex) else {
            return .accentColor
        }
        return color
    }

    private var greetingText: String {
        guard let displayName = resolvedDisplayName, !displayName.isEmpty else {
            return "onboarding.firstMission.greeting.generic".localized
        }
        return "onboarding.firstMission.greeting.named".localized(with: displayName)
    }

    private var resolvedDisplayName: String? {
        guard let raw = appState.currentUser?.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        let ignored = ["runner.defaultName".localized, "Runner", "Koşucu"]
        return ignored.contains(raw) ? nil : raw
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.04, green: 0.08, blue: 0.16),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            userColor
                .opacity(0.18)
                .blur(radius: 80)
                .frame(width: 320, height: 320)
                .offset(y: -180)
        }
    }

    // MARK: - Hero

    private var heroVisual: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                FirstMissionHexShape()
                    .stroke(
                        userColor.opacity(Double(5 - index) * 0.08),
                        lineWidth: 1.5
                    )
                    .frame(
                        width: 220 + CGFloat(index) * 30,
                        height: 220 + CGFloat(index) * 30
                    )
                    .scaleEffect(hexPulse ? 1.02 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: hexPulse
                    )
            }

            FirstMissionHexShape()
                .fill(
                    LinearGradient(
                        colors: [userColor, userColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 190, height: 190)
                .shadow(color: userColor.opacity(0.5), radius: 24, y: 8)
                .overlay(heroCharacter)
        }
    }

    @ViewBuilder
    private var heroCharacter: some View {
        if UIImage(named: "welcome_character") != nil {
            Image("welcome_character")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
        } else {
            Image(systemName: "figure.run")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Animation

    private func animateIn() {
        hexPulse = true
        withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
            contentVisible = true
        }
    }
}

// MARK: - Hex Shape

private struct FirstMissionHexShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let angle = (Double(i) * 60.0 - 30.0) * .pi / 180.0
            let point = CGPoint(
                x: center.x + radius * CGFloat(Foundation.cos(angle)),
                y: center.y + radius * CGFloat(Foundation.sin(angle))
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    FirstMissionView()
        .environmentObject(AppState())
        .environmentObject(AppRouter())
}
