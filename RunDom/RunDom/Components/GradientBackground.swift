import SwiftUI

struct GradientBackground: ViewModifier {
    var colors: [Color] = [.blue.opacity(0.15), .purple.opacity(0.1)]
    var startPoint: UnitPoint = .topLeading
    var endPoint: UnitPoint = .bottomTrailing

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: startPoint,
                    endPoint: endPoint
                )
                .ignoresSafeArea()
            )
    }
}

extension View {
    func gradientBackground(
        colors: [Color] = [.blue.opacity(0.15), .purple.opacity(0.1)],
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> some View {
        modifier(GradientBackground(colors: colors, startPoint: startPoint, endPoint: endPoint))
    }
}

#Preview {
    Text("Runpire")
        .font(.largeTitle.bold())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gradientBackground()
}
