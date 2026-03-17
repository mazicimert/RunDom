import SwiftUI
import Lottie

struct SplashView: View {
    let onFinish: () -> Void

    private let animationName = "Running_character"
    private let fallbackDuration: TimeInterval = 2.2
    private let characterSizeRatio: CGFloat = 0.36
    private let offscreenTravelPadding: CGFloat = 24
    private let movementDurationRatio: CGFloat = 0.90

    @State private var movementProgress: CGFloat = 0
    @State private var movementDidComplete = false
    @State private var hasStarted = false
    @State private var didFinish = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.01, green: 0.08, blue: 0.22),
                        Color(red: 0.03, green: 0.18, blue: 0.43),
                        Color(red: 0.06, green: 0.30, blue: 0.62)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay {
                    RadialGradient(
                        colors: [
                            Color(red: 0.28, green: 0.66, blue: 1.00).opacity(0.30),
                            Color(red: 0.14, green: 0.46, blue: 0.86).opacity(0.14),
                            .clear
                        ],
                        center: .bottom,
                        startRadius: 36,
                        endRadius: proxy.size.height * 0.62
                    )
                }
                .ignoresSafeArea()

                Text("Runpire")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .position(
                        x: proxy.size.width / 2,
                        y: max(64, proxy.size.height * 0.22)
                    )

                let characterSize = min(proxy.size.width * characterSizeRatio, 180)
                let yPosition = proxy.size.height * 0.55
                let startX = -(characterSize / 2) - offscreenTravelPadding
                let endX = proxy.size.width + (characterSize / 2) + offscreenTravelPadding

                LottieView(
                    animationName: animationName,
                    loopMode: .playOnce,
                    contentMode: .scaleAspectFit
                )
                .frame(width: characterSize, height: characterSize)
                .position(
                    x: startX + (endX - startX) * movementProgress,
                    y: yPosition
                )
            }
            .onAppear {
                startIfNeeded()
            }
        }
    }

    private func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        let duration = resolveDuration()
        let movementDuration = max(0.65, duration * movementDurationRatio)

        withAnimation(.linear(duration: movementDuration)) {
            movementProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + movementDuration) {
            movementDidComplete = true
            completeIfNeeded()
        }
    }

    private func resolveDuration() -> TimeInterval {
        let lottieDuration = LottieAnimation.named(animationName)?.duration
        return max(0.8, lottieDuration ?? fallbackDuration)
    }

    private func completeIfNeeded() {
        guard movementDidComplete, !didFinish else { return }
        didFinish = true
        onFinish()
    }
}

#Preview {
    SplashView(onFinish: {})
}
