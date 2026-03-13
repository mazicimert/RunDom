import SwiftUI

struct AvatarView: View {
    let photoURL: String?
    let userColor: String
    var size: CGFloat = 100

    var body: some View {
        Group {
            if let photoURL, let url = URL(string: photoURL) {
                CachedImageView(url: url)
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(hex: userColor) ?? .accentColor, lineWidth: 3)
        )
        .accessibilityLabel("avatar".localized)
    }

    private var placeholderView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            (Color(hex: userColor) ?? .blue).opacity(0.6),
                            (Color(hex: userColor) ?? .purple).opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "person.fill")
                .font(.system(size: size * 0.35))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AvatarView(photoURL: nil, userColor: "#4ECDC4", size: 100)
        AvatarView(photoURL: nil, userColor: "#FF6B6B", size: 64)
    }
}
