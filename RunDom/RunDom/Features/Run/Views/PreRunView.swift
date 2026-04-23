import SwiftUI

struct PreRunView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var unitPreference: UnitPreference
    @StateObject private var viewModel: PreRunViewModel
    let onStartRun: (RunMode) -> Void

    init(locationManager: LocationManager, onStartRun: @escaping (RunMode) -> Void) {
        _viewModel = StateObject(wrappedValue: PreRunViewModel(locationManager: locationManager))
        self.onStartRun = onStartRun
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
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
                    Haptics.impact(.medium)
                    onStartRun(viewModel.selectedMode)
                }
                .accessibilityHint("accessibility.run.startHint".localized)
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)
            .padding(.vertical, 16)
        }
        .navigationTitle("tab.run".localized)
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
        VStack(alignment: .leading, spacing: 14) {
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
        HStack(spacing: 8) {
            Image(systemName: badge.icon)
            Text(badge.title)
        }
        .font(.caption.bold())
        .foregroundStyle(badge.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(badge.color.opacity(0.12), in: Capsule())
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
        VStack(alignment: .leading, spacing: 14) {
            Text("run.selectMode".localized)
                .font(.headline.bold())
                .padding(.horizontal, AppConstants.UI.screenPadding)

            VStack(spacing: 14) {
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
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("challenge.sectionTitle".localized)
                            .font(.headline)

                        Text(
                            state.selectedChallenge == nil
                                ? "challenge.compact.subtitle.pending".localized
                                : "challenge.compact.subtitle.active".localized
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if state.selectedChallenge == nil {
                        Button("challenge.compact.open".localized) {
                            viewModel.presentChallengeSelection()
                        }
                        .font(.caption.bold())
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

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: challenge.difficulty == .safe ? "shield.fill" : "sparkles")
                    .font(.subheadline.bold())
                    .foregroundStyle(accentColor)
                    .frame(width: 38, height: 38)
                    .background(accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.localizedTitle)
                        .font(.subheadline.weight(.semibold))

                    Text(isCompleted ? "challenge.completed".localized : challenge.progressText(for: progressValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(challenge.rewardText)
                    .font(.caption.bold())
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(accentColor.opacity(0.12), in: Capsule())
            }

            ProgressView(value: progressFraction)
                .tint(accentColor)
        }
        .padding(16)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accentColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var compactUnselectedChallengeCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "target")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("challenge.compact.pendingTitle".localized)
                    .font(.subheadline.weight(.semibold))

                Text("challenge.compact.pendingBody".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: icon)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(isSelected ? .white : color)
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(isSelected ? color : color.opacity(0.16))
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(modeTag(for: mode))
                            .font(.caption.bold())
                            .foregroundStyle(isSelected ? color : .secondary)

                        Text(title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    if isSelected {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("run.modeSelected".localized)
                        }
                        .font(.caption.bold())
                        .foregroundStyle(color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(color.opacity(0.14), in: Capsule())
                    } else {
                        Image(systemName: "circle")
                            .font(.title3)
                            .foregroundStyle(.secondary.opacity(0.7))
                            .padding(.top, 2)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(modeHighlights(for: mode), id: \.self) { highlight in
                        Text(highlight)
                            .font(.caption.bold())
                            .foregroundStyle(isSelected ? color : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isSelected ? color.opacity(0.14) : color.opacity(0.08))
                            )
                    }
                }
            }
            .padding(AppConstants.UI.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [color.opacity(0.22), color.opacity(0.08)]
                                : [Color(.secondarySystemBackground), Color(.secondarySystemBackground)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                    .stroke(isSelected ? color.opacity(0.9) : Color.primary.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous))
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

    private func modeHighlights(for mode: RunMode) -> [String] {
        switch mode {
        case .normal:
            return [
                "run.modeNormal.feature1".localized,
                "run.modeNormal.feature2".localized
            ]
        case .boost:
            return [
                "run.modeBoost.feature1".localized(with: boostThresholdText),
                "run.modeBoost.feature2".localized(with: viewModel.boostMultiplierText)
            ]
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
            .padding(.horizontal, 52)
            .padding(.vertical, 16)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.accentColor.opacity(0.38), radius: 16, x: 0, y: 6)
            }
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(StartRunButtonStyle())
        .disabled(!isEnabled)
        .frame(maxWidth: .infinity)
    }
}

private struct StartRunButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct RunHeaderBadge: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
}
