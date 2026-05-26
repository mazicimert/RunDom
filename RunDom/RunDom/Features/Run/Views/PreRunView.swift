import SwiftUI

struct PreRunView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var unitPreference: UnitPreference
    @StateObject private var viewModel: PreRunViewModel
    @State private var showWhenInUseUpgradePrompt = false
    let onStartRun: (RunMode) -> Void

    private let cardCornerRadius: CGFloat = 20

    init(locationManager: LocationManager, onStartRun: @escaping (RunMode) -> Void) {
        _viewModel = StateObject(wrappedValue: PreRunViewModel(locationManager: locationManager))
        self.onStartRun = onStartRun
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                headerSection
                    .padding(.horizontal, AppConstants.UI.screenPadding)

                modesSection

                dailyChallengeSection

                if let reward = viewModel.dailyChallengeReward {
                    rewardBanner(reward)
                        .padding(.horizontal, AppConstants.UI.screenPadding)
                }

                if !viewModel.isLocationReady || viewModel.streakInfo != nil {
                    footerStatusRow
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, AppConstants.UI.screenPadding)
                }
            }
            .padding(.vertical, 24)
        }
        .refreshable {
            await reloadScreen()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }

                StartRunButton(isEnabled: viewModel.isLocationReady) {
                    guard viewModel.canStartRun() else { return }
                    if !viewModel.hasAlwaysPermission {
                        AnalyticsService.logPreRunBackgroundUpgradePromptShown()
                        showWhenInUseUpgradePrompt = true
                        return
                    }
                    Haptics.impact(.medium)
                    onStartRun(viewModel.selectedMode)
                }
                .accessibilityHint("accessibility.run.startHint".localized)
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)
            .padding(.vertical, 16)
        }
        .navigationTitle("tab.run".localized)
        .alert(
            "run.whenInUseUpgrade.title".localized,
            isPresented: $showWhenInUseUpgradePrompt
        ) {
            Button("run.whenInUseUpgrade.openSettings".localized) {
                AnalyticsService.logPreRunBackgroundUpgradeOpenSettings()
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("run.whenInUseUpgrade.startAnyway".localized) {
                AnalyticsService.logPreRunBackgroundUpgradeStartAnyway()
                Haptics.impact(.medium)
                onStartRun(viewModel.selectedMode)
            }
            Button("common.cancel".localized, role: .cancel) {
                AnalyticsService.logPreRunBackgroundUpgradeDismissed()
            }
        } message: {
            Text("run.whenInUseUpgrade.message".localized)
        }
        .fullScreenCover(isPresented: $viewModel.isChallengeSelectionPresented) {
            if let state = viewModel.dailyChallengeState {
                DailyChallengeSelectionView(
                    state: state,
                    isSelecting: viewModel.isSelectingChallenge,
                    onClose: {
                        viewModel.dismissChallengeSelection()
                    },
                    onSelect: { challenge in
                        selectChallenge(challenge)
                    }
                )
            }
        }
        .task(id: appState.currentUser?.id) {
            await reloadScreen()
        }
    }

    private func reloadScreen() async {
        await viewModel.load(user: appState.currentUser)
    }

    private func selectChallenge(_ challenge: DailyChallengeTemplate) {
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
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("run.header.title".localized)
                .font(.title2.bold())

            Text("run.header.subtitle".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(headerBadges) { badge in
                        headerBadge(badge)
                    }
                }
            }
        }
    }

    private var headerBadges: [RunHeaderBadge] {
        var badges: [RunHeaderBadge] = [
            RunHeaderBadge(
                title: gpsBadgeTitle,
                icon: gpsBadgeIcon,
                color: gpsBadgeColor
            )
        ]

        if let streak = viewModel.streakInfo, streak.days > 0 {
            badges.append(
                RunHeaderBadge(
                    title: "run.header.badge.streak".localized(with: "\(streak.days)"),
                    icon: "flame.fill",
                    color: streak.isAtRisk ? .red : .orange
                )
            )
        }

        if let selectedChallenge = viewModel.selectedChallenge {
            badges.append(
                RunHeaderBadge(
                    title: selectedChallenge.difficulty == .safe
                        ? "run.header.badge.challenge.safe".localized
                        : "run.header.badge.challenge.difficult".localized,
                    icon: "target",
                    color: challengeAccentColor(for: selectedChallenge)
                )
            )
        } else if viewModel.dailyChallengeState != nil {
            badges.append(
                RunHeaderBadge(
                    title: "run.header.badge.challenge.pending".localized,
                    icon: "target",
                    color: .secondary
                )
            )
        }

        return badges
    }

    private func headerBadge(_ badge: RunHeaderBadge) -> some View {
        HStack(spacing: 6) {
            Image(systemName: badge.icon)
                .foregroundStyle(badge.color)
            Text(badge.title)
                .foregroundStyle(.primary.opacity(0.85))
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.cardBackground, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var gpsBadgeTitle: String {
        if !viewModel.hasLocationPermission {
            return "run.header.badge.gps.permission".localized
        }

        return viewModel.isLocationReady
            ? "run.header.badge.gps.ready".localized
            : "run.header.badge.gps.searching".localized
    }

    private var gpsBadgeIcon: String {
        if !viewModel.hasLocationPermission {
            return "location.slash"
        }

        return viewModel.isLocationReady ? "location.fill" : "location.north.line.fill"
    }

    private var gpsBadgeColor: Color {
        if !viewModel.hasLocationPermission {
            return .red
        }

        return viewModel.isLocationReady ? .boostGreen : .orange
    }

    // MARK: - Mode Section

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("run.selectMode".localized)
                .font(.headline)
                .padding(.horizontal, AppConstants.UI.screenPadding)

            VStack(spacing: 12) {
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
                    description: "run.boostMode.desc".localized(
                        with: boostThresholdText,
                        viewModel.boostMultiplierText
                    ),
                    color: .orange
                )
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)
        }
    }

    // MARK: - Daily Challenge

    @ViewBuilder
    private var dailyChallengeSection: some View {
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("challenge.sectionTitle".localized)
                        .font(.headline)

                    Spacer()

                    if state.selectedChallenge == nil {
                        Button("challenge.compact.open".localized) {
                            viewModel.presentChallengeSelection()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    }
                }

                if let selectedChallenge = state.selectedChallenge {
                    compactChallengeCard(challenge: selectedChallenge, state: state)
                } else {
                    compactUnselectedChallengeCard
                }
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)
        }
    }

    private func compactChallengeCard(challenge: DailyChallengeTemplate, state: DailyChallengeState) -> some View {
        let accentColor = challengeAccentColor(for: challenge)
        let progressValue = state.progressValue(for: challenge)
        let progressFraction = challenge.progressFraction(for: progressValue)
        let isCompleted = state.progress?.isCompleted == true

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: challenge.difficulty == .safe ? "shield.fill" : "sparkles")
                    .font(.subheadline.bold())
                    .foregroundStyle(accentColor)
                    .frame(width: 40, height: 40)
                    .background(accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(challenge.localizedTitle)
                        .font(.subheadline.weight(.semibold))

                    Text(isCompleted ? "challenge.completed".localized : challenge.progressText(for: progressValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(challenge.rewardText)
                    .font(.caption.bold())
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(accentColor.opacity(0.12), in: Capsule())
            }

            ProgressView(value: progressFraction)
                .tint(accentColor)
        }
        .padding(16)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var compactUnselectedChallengeCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "target")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("challenge.compact.pendingTitle".localized)
                    .font(.subheadline.weight(.semibold))

                Text("challenge.compact.pendingBody".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(16)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func rewardBanner(_ reward: DailyChallengeReward) -> some View {
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

    private func challengeAccentColor(for challenge: DailyChallengeTemplate) -> Color {
        switch challenge.difficulty {
        case .safe:
            return .boostGreen
        case .difficult:
            return .orange
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerStatusRow: some View {
        if !viewModel.isLocationReady {
            HStack(spacing: 8) {
                ProgressView()
                Text("run.waitingGPS".localized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if let streak = viewModel.streakInfo, streak.days > 0 {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(streak.isAtRisk ? .red : .orange)

                Text("run.streakMultiplier".localized(with: String(format: "%.1fx", streak.multiplier)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if streak.isAtRisk {
                    Text("run.streakAtRisk".localized)
                        .font(.footnote.bold())
                        .foregroundStyle(.red)
                }
            }
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
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 46, height: 46)
                    .background(
                        color.opacity(isSelected ? 0.18 : 0.12),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(modeTag(for: mode))
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(color)

                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? color : Color.secondary.opacity(0.4),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 14, height: 14)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(isSelected ? color.opacity(0.10) : Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? color.opacity(0.55) : Color.primary.opacity(0.06),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "accessibility.selected".localized : "accessibility.notSelected".localized)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func modeTag(for mode: RunMode) -> String {
        switch mode {
        case .normal:
            return "run.modeNormal.tag".localized
        case .boost:
            return "run.modeBoost.tag".localized
        }
    }

    private var boostThresholdText: String {
        let threshold = UnitPreference.speedValue(
            fromKilometersPerHour: AppConstants.Game.boostMinSpeedKmh,
            useMiles: unitPreference.useMiles
        )
        return "\(threshold.formattedDecimal(maxFractionDigits: 0)) \(unitPreference.speedUnitLabel)"
    }
}

private struct StartRunButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.subheadline.bold())
                Text("run.start".localized)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.accentColor.opacity(0.32), radius: 14, x: 0, y: 6)
            }
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(StartRunButtonStyle())
        .disabled(!isEnabled)
    }
}

private struct StartRunButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct RunHeaderBadge: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
}
