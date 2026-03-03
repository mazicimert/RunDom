import SwiftUI

/// Static placeholder for the avatar.
/// Rive integration is deferred — will be replaced with RiveViewModel
/// using state machine "Main Animation" and boolean inputs
/// (Talking Animation, Sad Animation, Happy Animation).
struct RiveAvatarView: View {
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "figure.run")
                .font(.system(size: size * 0.4))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("avatar".localized)
    }
}

#Preview {
    VStack(spacing: 20) {
        RiveAvatarView(size: 120)
        RiveAvatarView(size: 64)
    }
}
