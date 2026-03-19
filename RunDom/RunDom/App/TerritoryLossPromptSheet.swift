import SwiftUI

struct TerritoryLossPromptSheet: View {
    @ObservedObject var viewModel: TerritoryLossPromptViewModel
    let onDismiss: () -> Void
    let onShowOnMap: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("territoryLoss.prompt.title".localized)
                        .font(.title3.bold())

                    Text(viewModel.bodyText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if viewModel.events.count > 1 {
                    Text(viewModel.counterText)
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let selectedEvent = viewModel.selectedEvent {
                VStack(alignment: .leading, spacing: 10) {
                    Label(viewModel.locationText, systemImage: "mappin.and.ellipse")
                        .font(.headline)

                    if let capturedByText = viewModel.capturedByText {
                        Text(capturedByText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let capturedAtText = viewModel.capturedAtText {
                        Text(capturedAtText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
            }

            HStack(spacing: 12) {
                Button("territoryLoss.prompt.dismiss".localized) {
                    onDismiss()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("territoryLoss.prompt.showOnMap".localized) {
                    onShowOnMap()
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            if viewModel.events.count > 1 {
                HStack(spacing: 16) {
                    Button {
                        onPrevious()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.circle.fill")
                            Text("territoryLoss.prompt.previous".localized)
                        }
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.canGoPrevious ? Color.accentColor : .secondary)
                    .disabled(!viewModel.canGoPrevious)

                    Button {
                        onNext()
                    } label: {
                        HStack(spacing: 8) {
                            Text("territoryLoss.prompt.next".localized)
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.canGoNext ? Color.accentColor : .secondary)
                    .disabled(!viewModel.canGoNext)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
}
