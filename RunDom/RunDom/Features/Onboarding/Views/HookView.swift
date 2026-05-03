import Foundation
import SwiftUI

struct HookView: View {
    let onContinue: () -> Void

    @State private var titleVisible = false
    @State private var subtitleVisible = false
    @State private var ctaVisible = false
    @State private var hexPulse = false

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                Spacer(minLength: 60)

                hexagonHero
                    .frame(maxHeight: 360)

                Spacer(minLength: 24)

                VStack(spacing: 18) {
                    Text("onboarding.hook.title".localized)
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(titleVisible ? 1 : 0)
                        .offset(y: titleVisible ? 0 : 16)

                    Text("onboarding.hook.subtitle".localized)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .opacity(subtitleVisible ? 1 : 0)
                        .offset(y: subtitleVisible ? 0 : 12)
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)

                Spacer()

                Button {
                    Haptics.impact(.medium)
                    onContinue()
                } label: {
                    Text("onboarding.hook.cta".localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.bottom, 40)
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 20)
            }
        }
        .onAppear { animateIn() }
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
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: -120, y: -200)

            Circle()
                .fill(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: 140, y: 220)
        }
    }

    // MARK: - Hexagon hero

    private var hexagonHero: some View {
        ZStack {
            // Decorative hex grid
            ForEach(0..<5, id: \.self) { index in
                HexagonShape()
                    .stroke(
                        Color.accentColor.opacity(Double(5 - index) * 0.08),
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

            // Center filled hex with welcome character
            HexagonShape()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 190, height: 190)
                .shadow(color: Color.accentColor.opacity(0.5), radius: 24, y: 8)
                .overlay(
                    heroCharacter
                )
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

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            titleVisible = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            subtitleVisible = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.55)) {
            ctaVisible = true
        }
        hexPulse = true
    }
}

// MARK: - Hexagon Shape

private struct HexagonShape: Shape {
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
    HookView(onContinue: {})
}
