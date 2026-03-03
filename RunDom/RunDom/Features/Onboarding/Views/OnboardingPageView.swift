import SwiftUI

struct OnboardingPageView: View {
    let icon: String
    let title: String
    let subtitle: String

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
                .scaleEffect(isAnimating ? 1.0 : 0.6)
                .opacity(isAnimating ? 1.0 : 0)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppConstants.UI.screenPadding)
            }
            .offset(y: isAnimating ? 0 : 20)
            .opacity(isAnimating ? 1.0 : 0)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

#Preview {
    OnboardingPageView(
        icon: "map.fill",
        title: "Conquer Your City",
        subtitle: "Run through real-world territories and claim them as your own."
    )
}
