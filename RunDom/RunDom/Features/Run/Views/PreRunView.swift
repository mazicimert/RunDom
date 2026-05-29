import SwiftUI

struct PreRunView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var unitPreference: UnitPreference
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: PreRunViewModel
    @State private var showWhenInUseUpgradePrompt = false
    let onStartRun: (RunMode) -> Void

    private let cardCornerRadius: CGFloat = 24

    init(locationManager: LocationManager, onStartRun: @escaping (RunMode) -> Void) {
        _viewModel = StateObject(wrappedValue: PreRunViewModel(locationManager: locationManager))
        self.onStartRun = onStartRun
    }

    var body: some View {
        ZStack {
            PreRunTheme.background
                .ignoresSafeArea()

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
                }
                .padding(.top, 14)
                .padding(.bottom, 116)
            }
        }
        .refreshable {
            await reloadScreen()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomActionBar
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(Color.primary.opacity(0.05))
                                .frame(height: 1)
                        }
                        .ignoresSafeArea()
                }
        }
        .navigationTitle("tab.run".localized)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
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

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }

            // Only meaningful status here is "searching" — permission states are
            // expressed by the primary button itself, so nothing competes with it.
            if viewModel.locationGate == .searching {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("run.waitingGPS".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }

            primaryActionButton
        }
        .animation(.easeInOut(duration: AppConstants.Animation.quick), value: viewModel.locationGate)
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        switch viewModel.locationGate {
        case .ready:
            StartRunButton(
                title: "run.start".localized,
                systemImage: "play.fill",
                isEnabled: true
            ) {
                startRunFlow()
            }
            .accessibilityHint("accessibility.run.startHint".localized)

        case .searching:
            StartRunButton(
                title: "run.start".localized,
                systemImage: "play.fill",
                isEnabled: false
            ) {}

        case .needsPermission:
            StartRunButton(
                title: "permission.location.button".localized,
                systemImage: "location.fill",
                isEnabled: true
            ) {
                Haptics.selection()
                viewModel.requestLocationPermission()
            }

        case .permissionDenied:
            StartRunButton(
                title: "run.whenInUseUpgrade.openSettings".localized,
                systemImage: "location.fill",
                isEnabled: true
            ) {
                openAppSettings()
            }
        }
    }

    private func startRunFlow() {
        guard viewModel.canStartRun() else { return }
        if !viewModel.hasAlwaysPermission {
            AnalyticsService.logPreRunBackgroundUpgradePromptShown()
            showWhenInUseUpgradePrompt = true
            return
        }
        Haptics.impact(.medium)
        onStartRun(viewModel.selectedMode)
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("run.header.title".localized)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.9))

            Text("run.header.subtitle".localized)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            if !headerBadges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(headerBadges) { badge in
                            headerBadge(badge)
                        }
                    }
                }
            }
        }
    }

    private var headerBadges: [RunHeaderBadge] {
        // GPS/permission state lives next to the Start button (see bottomActionBar),
        // so the header badges stay focused on identity/context: streak + challenge.
        var badges: [RunHeaderBadge] = []

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
                .foregroundStyle(.primary.opacity(0.82))
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(PreRunTheme.pillFill(for: colorScheme), in: Capsule())
        .overlay(
            Capsule()
                .stroke(PreRunTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: PreRunTheme.cardShadow(for: colorScheme), radius: 8, x: 0, y: 4)
    }

    // MARK: - Mode Section

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("run.selectMode".localized)
                .font(.system(.headline, design: .rounded))
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
                Text("challenge.sectionTitle".localized)
                    .font(.system(.headline, design: .rounded))

                if let selectedChallenge = state.selectedChallenge {
                    compactChallengeCard(challenge: selectedChallenge, state: state)
                } else {
                    Button {
                        Haptics.selection()
                        viewModel.presentChallengeSelection()
                    } label: {
                        compactUnselectedChallengeCard
                    }
                    .buttonStyle(.plain)
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
                    .background(accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

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
        .background(PreRunTheme.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(PreRunTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: PreRunTheme.cardShadow(for: colorScheme), radius: 20, x: 0, y: 10)
    }

    private var compactUnselectedChallengeCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "target")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("challenge.compact.pendingTitle".localized)
                    .font(.subheadline.weight(.semibold))

                Text("challenge.compact.pendingBody".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(PreRunTheme.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(PreRunTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: PreRunTheme.cardShadow(for: colorScheme), radius: 20, x: 0, y: 10)
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
        .background(Color.boostGreen.opacity(colorScheme == .dark ? 0.16 : 0.10), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.boostGreen.opacity(0.16), lineWidth: 1)
        }
    }

    private func challengeAccentColor(for challenge: DailyChallengeTemplate) -> Color {
        switch challenge.difficulty {
        case .safe:
            return .boostGreen
        case .difficult:
            return .orange
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
                    .font(.title3.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 52, height: 52)
                    .background(
                        color.opacity(isSelected ? 0.18 : 0.11),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(modeTag(for: mode))
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(color)

                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isSelected ? color : Color.secondary.opacity(0.45))
                    .frame(width: 28, height: 28)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(isSelected ? PreRunTheme.selectedCardFill(color: color, for: colorScheme) : PreRunTheme.cardFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? color.opacity(0.22) : PreRunTheme.cardBorder(for: colorScheme),
                        lineWidth: 1
                    )
            )
            .shadow(color: isSelected ? color.opacity(0.12) : PreRunTheme.cardShadow(for: colorScheme), radius: isSelected ? 22 : 18, x: 0, y: 10)
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
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.bold())
                Text(title)
                    .font(.system(.headline, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: buttonGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: buttonShadowColor, radius: 22, x: 0, y: 10)
            }
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(StartRunButtonStyle())
        .disabled(!isEnabled)
    }

    private var buttonGradientColors: [Color] {
        guard isEnabled else {
            return [Color.secondary.opacity(0.35), Color.secondary.opacity(0.25)]
        }

        return colorScheme == .dark
            ? [Color.boostGreen.opacity(0.95), Color.territoryBlue.opacity(0.95)]
            : [Color.boostGreen, Color.territoryBlue]
    }

    private var buttonShadowColor: Color {
        isEnabled
            ? Color.territoryBlue.opacity(colorScheme == .dark ? 0.22 : 0.16)
            : Color.clear
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

private enum PreRunTheme {
    /// Plain system background to match the other tabs.
    static var background: Color {
        Color(uiColor: .systemGroupedBackground)
    }

    static func cardFill(for colorScheme: ColorScheme) -> Color {
        Color.cardBackground
    }

    static func selectedCardFill(color: Color, for colorScheme: ColorScheme) -> Color {
        color.opacity(colorScheme == .dark ? 0.12 : 0.085)
    }

    static func pillFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color(uiColor: .secondarySystemGroupedBackground)
    }

    /// Hairline border — soft definition without a hard edge.
    static func cardBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.04)
    }

    /// Wide, very light shadow for an airy, premium feel.
    static func cardShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.22)
            : Color.black.opacity(0.04)
    }
}
