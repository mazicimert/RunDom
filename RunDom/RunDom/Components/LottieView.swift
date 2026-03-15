import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let animationName: String
    var loopMode: LottieLoopMode = .playOnce
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var animationSpeed: CGFloat = 1.0
    var onCompletion: (() -> Void)? = nil

    func makeUIView(context: Context) -> some UIView {
        let container = UIView(frame: .zero)
        let animationView = LottieAnimationView(name: animationName)
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

        animationView.play { finished in
            guard finished else { return }
            onCompletion?()
        }
        return container
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

#Preview {
    LottieView(animationName: "splash", loopMode: .loop)
        .frame(width: 200, height: 200)
}
