import SwiftUI

struct TerritoryLossMapBrowserBar: View {
    @ObservedObject var viewModel: TerritoryLossPromptViewModel
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("territoryLoss.prompt.mapBrowserTitle".localized)
                        .font(.headline)

                    Text(viewModel.locationText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let capturedByText = viewModel.capturedByText {
                        Text(capturedByText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(viewModel.counterText)
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.secondary)

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color(uiColor: .tertiarySystemBackground), in: Circle())
                    }
                    .accessibilityLabel("territoryLoss.prompt.closeBrowser".localized)
                }
            }

            HStack(spacing: 10) {
                Button(action: onPrevious) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.circle.fill")
                        Text("territoryLoss.prompt.previousShort".localized)
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .tertiarySystemBackground), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.canGoPrevious ? Color.accentColor : .secondary)
                .disabled(!viewModel.canGoPrevious)

                Button(action: onNext) {
                    HStack(spacing: 6) {
                        Text("territoryLoss.prompt.nextShort".localized)
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.canGoNext ? Color.accentColor : .secondary)
                .disabled(!viewModel.canGoNext)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
    }
}
