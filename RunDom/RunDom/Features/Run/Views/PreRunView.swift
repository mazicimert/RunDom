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
                        .appearTransition()

                    modesSection
                        .appearTransition(delay: 0.08)

                    dailyChallengeSection
                        .appearTransition(delay: 0.16)

                    if let reward = viewModel.dailyChallengeReward {
                        rewardBanner(reward)
                            .padding(.horizontal, AppConstants.UI.screenPadding)
                            .appearTransition(delay: 0.24)
                    }
                }
                .padding(.top, 8)
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
                        .fill(PreRunTheme.bottomChromeFill)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(PreRunTheme.bottomChromeDivider(for: colorScheme))
                                .frame(height: 0.5)
                        }
                        .ignoresSafeArea()
                }
        }
        .navigationTitle("tab.run".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(PreRunTheme.background, for: .navigationBar)
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
                HStack(spacing: 9) {
                    PulsingDot(color: .orange)
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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("run.header.title".localized)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("run.header.subtitle".localized)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }

            if !headerBadges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(headerBadges) { badge in
                            headerBadge(badge)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

            HStack(spacing: 14) {
                modeTile(mode: .normal, icon: "figure.run", title: "run.normalMode".localized, color: .blue, isBoost: false)
                modeTile(mode: .boost, icon: "bolt.fill", title: "run.boostMode".localized, color: .orange, isBoost: true)
            }

            // Description for the currently selected mode — one calm line,
            // crossfading as the choice changes.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(selectedModeDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .id(viewModel.selectedMode)
            .transition(.opacity)
            .animation(.easeInOut(duration: AppConstants.Animation.quick), value: viewModel.selectedMode)
        }
        .padding(.horizontal, AppConstants.UI.screenPadding)
    }

    private var selectedModeDescription: String {
        switch viewModel.selectedMode {
        case .normal:
            return "run.normalMode.desc".localized
        case .boost:
            return "run.boostMode.desc".localized(with: boostThresholdText, viewModel.boostMultiplierText)
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
        // Deliberately lighter than the selected card — a flat inset row so the
        // eye stays on the modes and the Start button.
        HStack(spacing: 12) {
            Image(systemName: "target")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(PreRunTheme.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PreRunTheme.cardBorder(for: colorScheme), lineWidth: 1)
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
    private func modeTile(mode: RunMode, icon: String, title: String, color: Color, isBoost: Bool) -> some View {
        let isSelected = viewModel.selectedMode == mode
        // Boost is the "exciting" mode: when selected it goes full-color with
        // light content; otherwise it keeps a faint warm tint so it reads special.
        let isBoostActive = isBoost && isSelected
        let contentColor: Color = isBoostActive ? .white : color

        Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: AppConstants.Animation.quick)) {
                viewModel.selectedMode = mode
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(contentColor)
                        .frame(width: 46, height: 46)
                        .background(
                            (isBoostActive ? Color.white.opacity(0.22) : color.opacity(isSelected ? 0.18 : 0.12)),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )

                    Spacer(minLength: 0)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isBoostActive ? .white : (isSelected ? color : Color.secondary.opacity(0.4)))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(modeTag(for: mode))
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(isBoostActive ? Color.white.opacity(0.9) : color)

                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(isBoostActive ? .white : .primary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tileBackground(color: color, isBoost: isBoost, isSelected: isSelected))
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(
                        isBoostActive ? Color.clear : (isSelected ? color.opacity(0.3) : PreRunTheme.cardBorder(for: colorScheme)),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: tileShadowColor(color: color, isBoost: isBoost, isSelected: isSelected),
                radius: isSelected ? 22 : 16,
                x: 0,
                y: 10
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "accessibility.selected".localized : "accessibility.notSelected".localized)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func tileBackground(color: Color, isBoost: Bool, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)

        if isBoost && isSelected {
            shape.fill(
                LinearGradient(
                    colors: [Color.orange, Color.boostRed],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else if isBoost {
            shape.fill(
                LinearGradient(
                    colors: [color.opacity(0.16), color.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            shape.fill(isSelected ? PreRunTheme.selectedCardFill(color: color, for: colorScheme) : PreRunTheme.cardFill(for: colorScheme))
        }
    }

    private func tileShadowColor(color: Color, isBoost: Bool, isSelected: Bool) -> Color {
        if isBoost && isSelected {
            return Color.orange.opacity(colorScheme == .dark ? 0.32 : 0.28)
        }
        if isSelected {
            return color.opacity(0.14)
        }
        return PreRunTheme.cardShadow(for: colorScheme)
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
                    .fill(buttonFill)
                    .shadow(color: buttonShadowColor, radius: 22, x: 0, y: 10)
            }
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(StartRunButtonStyle())
        .disabled(!isEnabled)
    }

    /// Rich monochrome blue: bright at the top, deeper at the bottom. Fixed tones
    /// (not the asset's lighter dark-mode variant) so it never washes out.
    private var buttonFill: AnyShapeStyle {
        guard isEnabled else { return AnyShapeStyle(Color.secondary.opacity(0.3)) }
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 0.27, green: 0.53, blue: 0.98),
                    Color(red: 0.11, green: 0.38, blue: 0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var buttonShadowColor: Color {
        isEnabled
            ? Color(red: 0.15, green: 0.40, blue: 0.90).opacity(colorScheme == .dark ? 0.30 : 0.24)
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

// MARK: - Motion Helpers

/// Subtle staggered entrance: fade + rise. Keeps the screen feeling alive
/// without drawing attention to itself.
private struct AppearTransition: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45).delay(delay)) {
                    shown = true
                }
            }
    }
}

private extension View {
    func appearTransition(delay: Double = 0) -> some View {
        modifier(AppearTransition(delay: delay))
    }
}

/// A soft pulsing dot used for the "searching for GPS" state.
private struct PulsingDot: View {
    var color: Color
    @State private var animating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .overlay {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(animating ? 2.2 : 1)
                    .opacity(animating ? 0 : 0.6)
            }
            .onAppear { animating = true }
            .animation(
                .easeOut(duration: 1.1).repeatForever(autoreverses: false),
                value: animating
            )
    }
}

private enum PreRunTheme {
    /// Plain system background to match the other tabs.
    static var background: Color {
        Color(uiColor: .systemGroupedBackground)
    }

    static var bottomChromeFill: Color {
        Color(uiColor: .secondarySystemBackground)
    }

    static func bottomChromeDivider(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
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
