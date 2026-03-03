import SwiftUI

// MARK: - Card Style

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppConstants.UI.cardPadding)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Screen Padding

extension View {
    func screenPadding() -> some View {
        padding(.horizontal, AppConstants.UI.screenPadding)
    }
}
