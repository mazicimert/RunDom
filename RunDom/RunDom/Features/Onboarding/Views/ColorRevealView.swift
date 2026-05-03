import Foundation
import SwiftUI

struct ColorRevealView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @State private var hexPulse = false
    @State private var revealVisible = false
    @State private var showConfetti = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, AppConstants.UI.screenPadding)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 28) {
                        hexagonHero
                            .frame(height: 280)
                            .padding(.top, 12)

                        VStack(spacing: 6) {
                            Text("onboarding.colorReveal.title".localized)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(1.2)

                            Text(currentColorName)
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(currentColor)
                                .multilineTextAlignment(.center)
                                .contentTransition(.opacity)
                        }
                        .opacity(revealVisible ? 1 : 0)

                        Text("onboarding.colorReveal.subtitle".localized)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppConstants.UI.screenPadding)
                            .opacity(revealVisible ? 1 : 0)

                        VStack(spacing: 14) {
                            Text("onboarding.colorReveal.changeHint".localized)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.45))
                                .textCase(.uppercase)
                                .tracking(1)

                            colorGrid
                        }
                        .padding(.horizontal, AppConstants.UI.screenPadding)
                        .padding(.top, 8)
                        .opacity(revealVisible ? 1 : 0)
                    }
                    .padding(.bottom, 24)
                }

                Button {
                    viewModel.confirmColorReveal()
                } label: {
                    Text("onboarding.colorReveal.cta".localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.bottom, 32)
            }

            if showConfetti {
                LottieView(
                    animationName: "confetti",
                    loopMode: .playOnce,
                    contentMode: .scaleAspectFill,
                    onCompletion: { showConfetti = false }
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        .onAppear { animateIn() }
    }

    // MARK: - Derived

    private var currentColor: Color {
        Color(hex: viewModel.pendingColor) ?? Color.accentColor
    }

    private var currentColorName: String {
        guard !viewModel.pendingColor.isEmpty else { return "" }
        let cleaned = viewModel.pendingColor.replacingOccurrences(of: "#", with: "").uppercased()
        return "color.name.\(cleaned)".localized
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

            currentColor
                .opacity(0.18)
                .blur(radius: 80)
                .frame(width: 320, height: 320)
                .offset(y: -200)
                .animation(.easeInOut(duration: 0.4), value: viewModel.pendingColor)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button {
                viewModel.backFromColorReveal()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            Spacer()
        }
    }

    // MARK: - Hexagon Hero

    private var hexagonHero: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                HexShape()
                    .stroke(
                        currentColor.opacity(Double(5 - index) * 0.08),
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

            HexShape()
                .fill(
                    LinearGradient(
                        colors: [currentColor, currentColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 190, height: 190)
                .shadow(color: currentColor.opacity(0.5), radius: 24, y: 8)
                .overlay(heroCharacter)
                .animation(.easeInOut(duration: 0.35), value: viewModel.pendingColor)
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

    // MARK: - Color Grid

    private var colorGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(viewModel.availableColors, id: \.self) { hex in
                ColorChoiceTile(
                    hex: hex,
                    isSelected: viewModel.pendingColor == hex
                ) {
                    viewModel.selectColor(hex)
                }
            }
        }
    }

    private func animateIn() {
        hexPulse = true
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            revealVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showConfetti = true
        }
    }
}

// MARK: - Color Tile

private struct ColorChoiceTile: View {
    let hex: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color(hex: hex) ?? .white)
                    .shadow(color: (Color(hex: hex) ?? .white).opacity(isSelected ? 0.55 : 0.25), radius: isSelected ? 10 : 4, y: 3)

                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)

                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                }
            }
            .frame(height: 60)
            .scaleEffect(isSelected ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Hex Shape

private struct HexShape: Shape {
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
    let vm = OnboardingViewModel()
    vm.pendingColor = "#4ECDC4"
    return ColorRevealView(viewModel: vm)
}
