import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void

    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var titleOffset: CGFloat = 30

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "figure.run")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Text("RunDom")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .offset(y: titleOffset)
                    .opacity(logoOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
                titleOffset = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Animation.splash) {
                onFinish()
            }
        }
    }
}

#Preview {
    SplashView(onFinish: {})
}
