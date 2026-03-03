import SwiftUI

struct ErrorBannerView: View {
    let message: String
    var onDismiss: (() -> Void)? = nil
    var onRetry: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            if let onRetry {
                Button {
                    onRetry()
                } label: {
                    Text("common.retry".localized)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
            }

            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, AppConstants.UI.cardPadding)
        .padding(.vertical, 12)
        .background(Color.red.gradient)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.smallCornerRadius, style: .continuous))
        .padding(.horizontal, AppConstants.UI.screenPadding)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    VStack {
        ErrorBannerView(
            message: "error.generic".localized,
            onDismiss: {},
            onRetry: {}
        )
        Spacer()
    }
}
