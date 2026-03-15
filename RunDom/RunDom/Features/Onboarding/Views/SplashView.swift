import SwiftUI
import Lottie

struct SplashView: View {
    let onFinish: () -> Void

    private let animationName = "Running_character"
    private let fallbackDuration: TimeInterval = 2.2
    private let characterSizeRatio: CGFloat = 0.36
    private let horizontalPadding: CGFloat = 24

    @State private var movementProgress: CGFloat = 0
    @State private var movementDidComplete = false
    @State private var lottieDidComplete = false
    @State private var hasStarted = false
    @State private var didFinish = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.95),
                        Color.accentColor.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
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
                let startX = horizontalPadding + (characterSize / 2)
                let endX = proxy.size.width - horizontalPadding - (characterSize / 2)

                LottieView(
                    animationName: animationName,
                    loopMode: .playOnce,
                    contentMode: .scaleAspectFit,
                    onCompletion: {
                        lottieDidComplete = true
                        completeIfNeeded()
                    }
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

        withAnimation(.linear(duration: duration)) {
            movementProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            movementDidComplete = true
            completeIfNeeded()
        }

        // Safety net for missing/corrupted animation files.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.4) {
            if !lottieDidComplete {
                lottieDidComplete = true
                completeIfNeeded()
            }
        }
    }

    private func resolveDuration() -> TimeInterval {
        let lottieDuration = LottieAnimation.named(animationName)?.duration
        return max(0.8, lottieDuration ?? fallbackDuration)
    }

    private func completeIfNeeded() {
        guard movementDidComplete, lottieDidComplete, !didFinish else { return }
        didFinish = true
        onFinish()
    }
}

#Preview {
    SplashView(onFinish: {})
}
