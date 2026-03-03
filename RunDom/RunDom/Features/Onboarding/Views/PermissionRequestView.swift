import SwiftUI

struct PermissionRequestView: View {
    enum PermissionType {
        case location
        case notification

        var icon: String {
            switch self {
            case .location: return "location.fill"
            case .notification: return "bell.badge.fill"
            }
        }

        var title: String {
            switch self {
            case .location: return "permission.location.title".localized
            case .notification: return "permission.notification.title".localized
            }
        }

        var subtitle: String {
            switch self {
            case .location: return "permission.location.subtitle".localized
            case .notification: return "permission.notification.subtitle".localized
            }
        }

        var buttonTitle: String {
            switch self {
            case .location: return "permission.location.button".localized
            case .notification: return "permission.notification.button".localized
            }
        }

        var iconColor: Color {
            switch self {
            case .location: return .blue
            case .notification: return .orange
            }
        }
    }

    let type: PermissionType
    let onAllow: () -> Void
    let onSkip: () -> Void

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(type.iconColor.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: type.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(type.iconColor)
            }
            .scaleEffect(isAnimating ? 1.0 : 0.7)
            .opacity(isAnimating ? 1.0 : 0)

            // Text
            VStack(spacing: 12) {
                Text(type.title)
                    .font(.title2.bold())

                Text(type.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppConstants.UI.screenPadding)
            }
            .offset(y: isAnimating ? 0 : 15)
            .opacity(isAnimating ? 1.0 : 0)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(type.buttonTitle) {
                    onAllow()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("common.skip".localized) {
                    onSkip()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    PermissionRequestView(
        type: .location,
        onAllow: {},
        onSkip: {}
    )
}
