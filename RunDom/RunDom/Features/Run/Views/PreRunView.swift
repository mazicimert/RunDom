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
        VStack(spacing: 16) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Text("run.selectMode".localized)
                        .font(.title.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppConstants.UI.screenPadding)

                    dailyChallengesSection

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

                    if let streak = viewModel.streakInfo, streak.days > 0 {
                        streakBanner(streak: streak)
                            .padding(.horizontal, AppConstants.UI.screenPadding)
                    }
                }
                .padding(.vertical, 24)
            }
            .refreshable {
                await reloadScreen()
            }

            if !viewModel.isLocationReady {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("run.waitingGPS".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

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
            .accessibilityHint("accessibility.run.startHint".localized)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .navigationTitle("tab.run".localized)
        .task(id: appState.currentUser?.id) {
            await reloadScreen()
        }
    }

    private func reloadScreen() async {
        await viewModel.load(user: appState.currentUser)
    }

    // MARK: - Daily Challenges

    @ViewBuilder
    private var dailyChallengesSection: some View {
        if viewModel.isLoadingChallenges {
            HStack(spacing: 10) {
                ProgressView()
                Text("challenge.loading".localized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppConstants.UI.screenPadding)
        } else if let state = viewModel.dailyChallengeState {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("challenge.sectionTitle".localized)
                        .font(.headline)

                    Text("challenge.sectionSubtitle".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(state.challenges) { challenge in
                    challengeCard(challenge: challenge, state: state)
                }

                if let reward = viewModel.dailyChallengeReward {
                    Label(
                        "challenge.reward.granted".localized(with: reward.bonusTrail.formattedTrail),
                        systemImage: "sparkles"
                    )
                    .font(.footnote.bold())
                    .foregroundStyle(.boostGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.boostGreen.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)
        }
    }

    @ViewBuilder
    private func challengeCard(challenge: DailyChallengeTemplate, state: DailyChallengeState) -> some View {
        let isSelected = state.isSelected(challenge)
        let isLocked = state.isLocked(challenge)
        let progressValue = state.progressValue(for: challenge)
        let progressFraction = challenge.progressFraction(for: progressValue)
        let accentColor: Color = challenge.difficulty == .safe ? .boostGreen : .boostRed

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text(challenge.difficulty.localizedLabel)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accentColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(accentColor)

                Spacer()

                Text(challenge.rewardText)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }

            Text(challenge.localizedTitle)
                .font(.headline)

            ProgressView(value: progressFraction)
                .tint(accentColor)

            HStack {
                Text(isSelected ? challenge.progressText(for: progressValue) : challenge.targetText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if isSelected, state.progress?.isCompleted == true {
                    Text("challenge.completed".localized)
                        .font(.caption.bold())
                        .foregroundStyle(accentColor)
                }
            }

            if isSelected {
                statusChip(
                    title: state.progress?.isCompleted == true
                        ? "challenge.completed".localized
                        : "challenge.selected".localized,
                    color: accentColor
                )
            } else if isLocked {
                statusChip(
                    title: "challenge.locked".localized,
                    color: .secondary
                )
            } else {
                Button {
                    guard let userId = appState.currentUser?.id else { return }
                    Task {
                        let result = await viewModel.selectDailyChallenge(
                            challengeId: challenge.id,
                            userId: userId
                        )
                        if result?.didGrantReward == true {
                            await appState.loadCurrentUser()
                        }
                    }
                } label: {
                    Text("challenge.select".localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isSelectingChallenge)
            }
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                .stroke(isSelected ? accentColor : .clear, lineWidth: 2)
        )
        .opacity(isLocked ? 0.68 : 1.0)
    }

    private func statusChip(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.12), in: Capsule())
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
