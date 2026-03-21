import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let animationName: String
    var loopMode: LottieLoopMode = .playOnce
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var animationSpeed: CGFloat = 1.0
    var onCompletion: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        let configuration = LottieConfiguration(renderingEngine: .mainThread)
        let animation = LottieAnimation.named(animationName)
        let animationView = LottieAnimationView(animation: animation, configuration: configuration)

        animationView.backgroundBehavior = .forceFinish
        animationView.loopMode = loopMode
        animationView.contentMode = contentMode
        animationView.animationSpeed = animationSpeed
        animationView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        context.coordinator.animationView = animationView
        context.coordinator.onCompletion = onCompletion
        context.coordinator.startPlaybackIfNeeded()

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Only update the completion handler — do NOT re-set animationView
        // properties during playback, as that restarts the animation.
        context.coordinator.onCompletion = onCompletion
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator {
        var animationView: LottieAnimationView?
        var onCompletion: (() -> Void)?
        private var didStartPlayback = false

        func startPlaybackIfNeeded() {
            guard !didStartPlayback, let animationView else { return }
            didStartPlayback = true

            animationView.play { [weak self] finished in
                guard finished else { return }
                DispatchQueue.main.async {
                    self?.onCompletion?()
                }
            }
        }

        func teardown() {
            animationView?.stop()
            animationView?.removeFromSuperview()
            animationView = nil
            onCompletion = nil
            didStartPlayback = false
        }
    }
}

#Preview {
    LottieView(animationName: "splash", loopMode: .loop)
        .frame(width: 200, height: 200)
}
