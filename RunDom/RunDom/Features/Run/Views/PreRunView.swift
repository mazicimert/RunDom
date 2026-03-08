import SwiftUI

struct PreRunView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: PreRunViewModel
    let onStartRun: (RunMode) -> Void

    init(locationManager: LocationManager, onStartRun: @escaping (RunMode) -> Void) {
        _viewModel = StateObject(wrappedValue: PreRunViewModel(locationManager: locationManager))
        self.onStartRun = onStartRun
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text("run.selectMode".localized)
                .font(.title.bold())

            // Mode Cards
            VStack(spacing: 16) {
                modeCard(
                    mode: .normal,
                    icon: "figure.run",
                    title: "run.normalMode".localized,
                    description: "run.normalMode.desc".localized,
                    color: .blue
                )

                modeCard(
                    mode: .boost,
                    icon: "bolt.fill",
                    title: "run.boostMode".localized,
                    description: "run.boostMode.desc".localized(with: viewModel.boostThresholdText, viewModel.boostMultiplierText),
                    color: .orange
                )
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)

            // Streak Info
            if let streak = viewModel.streakInfo, streak.days > 0 {
                streakBanner(streak: streak)
                    .padding(.horizontal, AppConstants.UI.screenPadding)
            }

            Spacer()

            // GPS Status
            if !viewModel.isLocationReady {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("run.waitingGPS".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // Start Button
            Button {
                guard viewModel.canStartRun() else { return }
                Haptics.impact(.medium)
                onStartRun(viewModel.selectedMode)
            } label: {
                Label("run.start".localized, systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.isLocationReady)
            .padding(.horizontal, AppConstants.UI.screenPadding)
            .padding(.bottom, 8)
            .accessibilityHint("accessibility.run.startHint".localized)

            // Error
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .navigationTitle("tab.run".localized)
        .onAppear {
            viewModel.loadStreakInfo(user: appState.currentUser)
        }
    }

    // MARK: - Mode Card

    @ViewBuilder
    private func modeCard(mode: RunMode, icon: String, title: String, description: String, color: Color) -> some View {
        let isSelected = viewModel.selectedMode == mode

        Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: AppConstants.Animation.quick)) {
                viewModel.selectedMode = mode
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? color : .secondary)
            }
            .padding(AppConstants.UI.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                    .stroke(isSelected ? color : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "accessibility.selected".localized : "accessibility.notSelected".localized)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Streak Banner

    @ViewBuilder
    private func streakBanner(streak: StreakService.StreakInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("run.streak".localized(with: "\(streak.days)"))
                    .font(.subheadline.bold())

                Text("run.streakMultiplier".localized(with: String(format: "%.1fx", streak.multiplier)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if streak.isAtRisk {
                Text("run.streakAtRisk".localized)
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.UI.smallCornerRadius)
                .fill(Color.orange.opacity(0.1))
        )
    }
}
