import SwiftUI
import MapKit
import UIKit

struct PostRunSummaryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: PostRunViewModel
    @State private var showConfetti = false
    @State private var showStreakFire = false
    @State private var showLevelUp = false
    @State private var isGalleryPresented = false
    @State private var showReviewSheet = false
    @State private var reviewBinding: RunReview?
    @State private var showNotificationPrompt = false
    @State private var showCreatePost = false
    @State private var hasSharedToFollowers = false
    let onDismiss: () -> Void

    init(session: RunSession, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: PostRunViewModel(session: session))
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            ZStack {
                summaryBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        heroSection
                        routeSummarySection
                        statsGrid

                        shareWithFollowersSection

                        if showsAchievementsSection {
                            achievementsSection
                        }

                        if let result = viewModel.trailResult {
                            multiplierBreakdown(result: result)
                        }

                        AIRunAnalysisLauncher(
                            session: viewModel.session,
                            trailResult: viewModel.trailResult,
                            neighborhood: appState.currentUser?.neighborhood
                        )

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .summarySurface(fill: summaryCardFill)
                        }

                        if viewModel.isSaving {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(.primary)
                                Text("run.saving".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .summarySurface(fill: summaryCardFill)
                        }

                        reviewActionSection
                    }
                    .padding(.horizontal, AppConstants.UI.screenPadding)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("run.summary".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.surfacePrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("run.done".localized) {
                        onDismiss()
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
            .fullScreenCover(isPresented: $isGalleryPresented) {
                RunGalleryView(session: viewModel.session)
            }
            .sheet(isPresented: $showReviewSheet) {
                RunReviewSheet(review: $reviewBinding) { review in
                    viewModel.submitReview(review)
                }
            }
            .sheet(isPresented: $showNotificationPrompt) {
                NotificationPostRunPromptSheet(
                    userColorHex: appState.currentUser?.color,
                    onComplete: {}
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCreatePost) {
                if let user = appState.currentUser {
                    CreatePostSheet(
                        session: viewModel.session,
                        author: user,
                        onPublished: { _ in
                            hasSharedToFollowers = true
                        }
                    )
                }
            }
            .task {
                if let user = appState.currentUser {
                    await viewModel.processRun(user: user)
                }
            }
            .onChange(of: viewModel.isSaved) { _, saved in
                if saved {
                    Task { await appState.loadCurrentUser() }
                    Haptics.notification(.success)
                    if viewModel.didLevelUp {
                        showLevelUp = true
                    } else if viewModel.didExtendStreak {
                        showStreakFire = true
                    } else {
                        showConfetti = true
                    }
                    scheduleNotificationPromptIfNeeded()
                }
            }
            .onChange(of: viewModel.errorMessage) { _, message in
                if message != nil { Haptics.notification(.error) }
            }
        }
        .overlay {
            ZStack {
                if showConfetti {
                    LottieView(
                        animationName: "confetti",
                        loopMode: .playOnce,
                        contentMode: .scaleAspectFill,
                        onCompletion: {
                            showConfetti = false
                        }
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                if showStreakFire {
                    VStack(spacing: 8) {
                        LottieView(
                            animationName: "Streak_fire",
                            loopMode: .playOnce,
                            animationSpeed: 0.95,
                            onCompletion: {
                                showStreakFire = false
                            }
                        )
                        .frame(width: 220, height: 220)

                        if let streakText = viewModel.streakExtendedText {
                            Text(streakText)
                                .font(.headline.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 32)
                    .allowsHitTesting(false)
                }

                if showLevelUp {
                    VStack(spacing: 12) {
                        LottieView(
                            animationName: "level_up",
                            loopMode: .playOnce,
                            onCompletion: {
                                showLevelUp = false
                            }
                        )
                        .frame(width: 260, height: 260)

                        VStack(spacing: 4) {
                            Text("run.summary.levelUp.title".localized)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)

                            if let level = viewModel.newLevel {
                                Text("profile.level.title".localized(with: level))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.55))
                        )
                    }
                    .padding(.top, 24)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showLevelUp)
        }
    }

    private var summaryBackground: some View {
        ZStack {
            Color.surfacePrimary

            LinearGradient(
                colors: [
                    Color.territoryBlue.opacity(0.04),
                    Color.clear,
                    Color.boostGreen.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.territoryBlue.opacity(0.07))
                .frame(width: 220, height: 220)
                .blur(radius: 100)
                .offset(x: -80, y: -260)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                modeBadge
                Spacer()

                if let streakText = viewModel.streakExtendedText, viewModel.didExtendStreak {
                    summaryChip(
                        icon: "flame.fill",
                        text: streakText,
                        tint: .orange
                    )
                }
            }

            VStack(spacing: 10) {
                Text(viewModel.performanceSummaryText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(viewModel.trailText)
                    .font(.system(size: isTrailVoided ? 54 : 68, weight: .black, design: .rounded))
                    .foregroundStyle(isTrailVoided ? Color.white.opacity(0.5) : .white)
                    .minimumScaleFactor(0.7)

                Text("run.trailEarned".localized)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))

                Text(viewModel.heroSubtitleText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)

                if let resultReasonText = viewModel.resultReasonText {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2.weight(.bold))
                            Text(resultReasonText)
                                .font(.caption.weight(.semibold))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(Color.boostYellow)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.38))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.boostYellow.opacity(0.5), lineWidth: 1)
                                )
                        )

                        Text("run.summary.voided.encourage".localized)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.16, blue: 0.26),
                            Color(red: 0.05, green: 0.07, blue: 0.13),
                            Color.black.opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.territoryBlue.opacity(0.22))
                        .frame(width: 160, height: 160)
                        .blur(radius: 18)
                        .offset(x: 18, y: -26)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.24), radius: 22, y: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(viewModel.trailText) \("run.trailEarned".localized). \(viewModel.performanceSummaryText). \(viewModel.heroSubtitleText)")
    }

    private var modeBadge: some View {
        let palette = modeBadgePalette

        return HStack(spacing: 8) {
            Image(systemName: palette.icon)
                .font(.caption.weight(.bold))
            Text(viewModel.modeBadgeText)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(palette.foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(palette.background)
        )
    }

    private var modeBadgePalette: (foreground: Color, background: Color, icon: String) {
        switch viewModel.modeBadgeKind {
        case .normal:
            return (.territoryBlue, Color.territoryBlue.opacity(0.18), "figure.run")
        case .boostActive:
            return (.orange, Color.orange.opacity(0.2), "bolt.fill")
        case .boostCancelled:
            return (.red, Color.red.opacity(0.2), "bolt.slash.fill")
        }
    }

    private var routeSummarySection: some View {
        Group {
            if viewModel.session.route.count >= 2 {
                VStack(alignment: .leading, spacing: 14) {
                    Text("run.summary.route".localized)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)

                    PostRunMapView(routePoints: viewModel.session.route)
                        .frame(height: 214)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        )
                }
                .summarySurface(fill: summaryCardFill)
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            PostRunCompactStatCard(
                icon: "ruler",
                value: viewModel.distanceKm.formattedDistance,
                label: "run.distance".localized
            )

            PostRunCompactStatCard(
                icon: "clock",
                value: viewModel.durationText,
                label: "run.duration".localized
            )

            PostRunCompactStatCard(
                icon: "timer",
                value: viewModel.avgPaceText,
                label: "run.avgPace".localized
            )

            PostRunCompactStatCard(
                icon: "map",
                value: "\(viewModel.session.territoriesCaptured)",
                label: "run.territories".localized
            )
        }
    }

    private var showsAchievementsSection: Bool {
        viewModel.didExtendStreak || viewModel.dailyChallengeReward != nil
    }

    @ViewBuilder
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("run.summary.achievements".localized)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                if viewModel.didExtendStreak, let streakText = viewModel.streakExtendedText {
                    achievementRow(
                        icon: "flame.fill",
                        tint: .orange,
                        title: "run.summary.achievement.streak".localized,
                        subtitle: streakText,
                        trailingText: streakText
                    )
                }

                if let reward = viewModel.dailyChallengeReward {
                    achievementRow(
                        icon: "flag.checkered.2.crossed",
                        tint: .boostGreen,
                        title: "run.summary.achievement.daily".localized,
                        subtitle: reward.challengeTitle,
                        trailingText: "challenge.reward.value".localized(with: reward.bonusTrail.formattedTrail)
                    )
                }
            }
        }
        .summarySurface(fill: summaryCardFill)
    }

    @ViewBuilder
    private func multiplierBreakdown(result: TrailCalculator.TrailResult) -> some View {
        let speedIsCause = isTrailVoided && result.speedMultiplier == 0

        VStack(alignment: .leading, spacing: 14) {
            Text("run.breakdown".localized)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            Text(!isTrailVoided
                 ? "run.summary.breakdown.subtitle".localized
                 : (result.speedMultiplier == 0
                    ? "run.summary.breakdown.voided.speed".localized
                    : "run.summary.breakdown.voided".localized))
                .font(.footnote)
                .foregroundStyle(isTrailVoided ? Color.boostYellow.opacity(0.92) : Color.secondary)

            VStack(spacing: 0) {
                ledgerRow(
                    label: "run.basePoints".localized,
                    value: String(format: "%.0f", result.basePoints),
                    tone: .neutral,
                    dimmed: isTrailVoided
                )
                ledgerDivider
                ledgerRow(
                    label: "run.speedMultiplier".localized,
                    value: multiplierText(for: result.speedMultiplier),
                    tone: multiplierTone(for: result.speedMultiplier),
                    dimmed: isTrailVoided && !speedIsCause,
                    isCause: speedIsCause
                )
                ledgerDivider
                ledgerRow(
                    label: "run.durationMultiplier".localized,
                    value: multiplierText(for: result.durationMultiplier),
                    tone: multiplierTone(for: result.durationMultiplier),
                    dimmed: isTrailVoided
                )
                ledgerDivider
                ledgerRow(
                    label: "run.zoneMultiplier".localized,
                    value: multiplierText(for: result.zoneMultiplier),
                    tone: multiplierTone(for: result.zoneMultiplier),
                    dimmed: isTrailVoided
                )
                ledgerDivider
                ledgerRow(
                    label: "run.streakMultiplier.label".localized,
                    value: multiplierText(for: result.streakMultiplier),
                    tone: multiplierTone(for: result.streakMultiplier),
                    dimmed: isTrailVoided
                )

                if result.modeMultiplier > 1.0 {
                    ledgerDivider
                    ledgerRow(
                        label: "run.boostMultiplier".localized,
                        value: multiplierText(for: result.modeMultiplier, decimals: 1),
                        tone: multiplierTone(for: result.modeMultiplier, decimals: 1),
                        dimmed: isTrailVoided
                    )
                }

                if result.antiFarmMultiplier < 1.0 {
                    ledgerDivider
                    ledgerRow(
                        label: "run.antiFarmMultiplier".localized,
                        value: multiplierText(for: result.antiFarmMultiplier),
                        tone: multiplierTone(for: result.antiFarmMultiplier),
                        dimmed: isTrailVoided
                    )
                }
            }

            Rectangle()
                .fill(Color.primary.opacity(0.14))
                .frame(height: 1)

            HStack(spacing: 10) {
                Text("run.trailEarned".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.trailText)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isTrailVoided ? Color.secondary : Color.primary)
            }

            if result.wasCapped || result.wasDailyCapped {
                VStack(alignment: .leading, spacing: 6) {
                    if result.wasCapped {
                        Text("run.capped".localized)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)
                    }

                    if result.wasDailyCapped {
                        Text("run.dailyCapped".localized)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.top, 2)
            }
        }
        .summarySurface(fill: summaryCardFill)
    }

    private var reviewActionSection: some View {
        Button {
            reviewBinding = viewModel.review
            showReviewSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.review?.hasContent == true ? "star.fill" : "star")
                Text(viewModel.review?.hasContent == true
                     ? "run.review.edit".localized
                     : "run.review.button".localized)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle())
        .padding(.top, 4)
    }

    @ViewBuilder
    private var shareWithFollowersSection: some View {
        if viewModel.isSaved && !isTrailVoided {
            if hasSharedToFollowers {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                    Text("social.share.shared".localized)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .summarySurface(fill: summaryCardFill)
            } else {
                Button {
                    showCreatePost = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.2.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.accentColor, in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("social.share.title".localized)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("social.share.subtitle".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .summarySurface(fill: summaryCardFill)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button(action: shareSummary) {
                summaryActionLabel(
                    title: "run.gallery".localized,
                    systemImage: "photo.on.rectangle.angled"
                )
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(!canShareSummary)

            Button(action: inspectRunOnMap) {
                summaryActionLabel(
                    title: "run.summary.viewOnMap".localized,
                    systemImage: "map.fill"
                )
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, AppConstants.UI.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            Color.surfacePrimary.opacity(0.96)
            .ignoresSafeArea()
        )
    }

    private var summaryCardFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.cardBackground,
                Color.cardBackground.opacity(0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var isTrailVoided: Bool {
        guard let result = viewModel.trailResult else { return false }
        return result.totalTrail == 0
    }

    private var canShareSummary: Bool {
        viewModel.trailResult != nil && !viewModel.isSaving
    }

    private func multiplierText(for value: Double, decimals: Int = 2) -> String {
        String(format: "×%.\(decimals)f", roundedMultiplierValue(value, decimals: decimals))
    }

    private func multiplierTone(for value: Double, decimals: Int = 2) -> BreakdownTone {
        let displayedValue = roundedMultiplierValue(value, decimals: decimals)

        if displayedValue > 1.0 {
            return .positive
        } else if displayedValue < 1.0 {
            return .negative
        }

        return .neutral
    }

    private func roundedMultiplierValue(_ value: Double, decimals: Int) -> Double {
        let precision = pow(10.0, Double(decimals))
        return (value * precision).rounded() / precision
    }

    private func summaryActionLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity)
    }

    private func summaryChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
        )
    }

    private func achievementRow(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        trailingText: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Text(trailingText)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(tint.opacity(0.14))
                )
        }
    }

    private var ledgerDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.07))
            .frame(height: 1)
    }

    private func ledgerRow(
        label: String,
        value: String,
        tone: BreakdownTone,
        dimmed: Bool = false,
        isCause: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(isCause ? Color.primary : Color.secondary)

            if isCause {
                Text("run.summary.breakdown.cause".localized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.15))
                    )
            }

            Spacer(minLength: 12)

            if let symbol = tone.trendSymbol {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tone.foreground)
            }

            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tone.foreground)
        }
        .padding(.vertical, 11)
        .opacity(dimmed ? 0.4 : 1.0)
    }

    private func inspectRunOnMap() {
        if let coordinate = viewModel.session.route.last?.coordinate ?? viewModel.session.route.first?.coordinate {
            router.focusMap(onTerritoryLoss: coordinate.h3Index())
        } else {
            router.selectedTab = .map
        }

        onDismiss()
    }

    private func shareSummary() {
        guard canShareSummary else { return }
        isGalleryPresented = true
    }

    private func scheduleNotificationPromptIfNeeded() {
        let alreadyAsked = UserDefaults.standard.bool(
            forKey: AppConstants.UserDefaultsKeys.hasRequestedNotificationPermission
        )
        guard !alreadyAsked else { return }

        // Let confetti / streak / level-up animations play first
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            showNotificationPrompt = true
        }
    }
}

// MARK: - Post Run Map View

struct PostRunMapView: UIViewRepresentable {
    let routePoints: [RoutePoint]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = false
        mapView.mapType = .standard
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard routePoints.count >= 2 else { return }

        let coordinates = routePoints.map(\.coordinate)
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        let startCoord = coordinates.first!
        let endCoord = coordinates.last!
        let startEndDistance = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
            .distance(from: CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude))

        // For very short routes the start/finish pins overlap, so collapse them into one.
        if startEndDistance < 25 {
            let routeAnnotation = MKPointAnnotation()
            routeAnnotation.coordinate = startCoord
            routeAnnotation.title = "run.route".localized
            mapView.addAnnotation(routeAnnotation)
        } else {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = startCoord
            startAnnotation.title = "run.startPoint".localized

            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = endCoord
            endAnnotation.title = "run.endPoint".localized

            mapView.addAnnotations([startAnnotation, endAnnotation])
        }

        let rect = polyline.boundingMapRect
        let metersPerPoint = MKMetersPerMapPointAtLatitude(startCoord.latitude)
        let rectSpanMeters = max(rect.size.width, rect.size.height) * metersPerPoint

        // Guarantee a sensible zoom level for tiny routes instead of zooming in to the max.
        if rectSpanMeters < 150 {
            let center = CLLocationCoordinate2D(
                latitude: (startCoord.latitude + endCoord.latitude) / 2,
                longitude: (startCoord.longitude + endCoord.longitude) / 2
            )
            let region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: 200,
                longitudinalMeters: 200
            )
            mapView.setRegion(region, animated: false)
        } else {
            let insets = UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)
            mapView.setVisibleMapRect(rect, edgePadding: insets, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

private enum BreakdownTone {
    case positive
    case negative
    case neutral

    var foreground: Color {
        switch self {
        case .positive:
            return .boostGreen
        case .negative:
            return .red
        case .neutral:
            return .primary
        }
    }

    var trendSymbol: String? {
        switch self {
        case .positive:
            return "arrow.up"
        case .negative:
            return "arrow.down"
        case .neutral:
            return nil
        }
    }
}

private struct PostRunCompactStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(.territoryBlue)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.territoryBlue.opacity(0.14))
                )

            Spacer(minLength: 0)

            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
        .summarySurface(
            fill: LinearGradient(
                colors: [
                    Color.cardBackground,
                    Color.cardBackground.opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private extension View {
    func summarySurface(fill: LinearGradient) -> some View {
        padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }
}
