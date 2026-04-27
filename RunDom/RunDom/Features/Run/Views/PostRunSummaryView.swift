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

                        if showsAchievementsSection {
                            achievementsSection
                        }

                        if let result = viewModel.trailResult {
                            multiplierBreakdown(result: result)
                        }

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
                                    .tint(.white)
                                Text("run.saving".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.78))
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
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)

                Text("run.trailEarned".localized)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))

                Text(viewModel.heroSubtitleText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
                    .multilineTextAlignment(.center)

                if let resultReasonText = viewModel.resultReasonText {
                    Text(resultReasonText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.boostYellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.boostYellow.opacity(0.14))
                        )
                        .multilineTextAlignment(.center)
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
                        .foregroundStyle(.white)

                    ZStack(alignment: .topLeading) {
                        PostRunMapView(routePoints: viewModel.session.route)
                            .frame(height: 214)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                            )

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                summaryChip(icon: "ruler", text: viewModel.distanceKm.formattedDistance, tint: .territoryBlue)
                                summaryChip(icon: "clock", text: viewModel.durationText, tint: .white)
                                summaryChip(icon: "map", text: "\(viewModel.session.territoriesCaptured)", tint: .boostGreen)
                            }
                            .padding(14)
                        }
                    }

                    HStack(spacing: 12) {
                        Text(viewModel.heroSubtitleText)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                        Spacer()
                    }
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
                icon: "speedometer",
                value: viewModel.avgSpeedText,
                label: "run.avgSpeed".localized
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
                .foregroundStyle(.white)

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
        VStack(alignment: .leading, spacing: 12) {
            Text("run.breakdown".localized)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text("run.summary.breakdown.subtitle".localized)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.64))

            VStack(spacing: 12) {
                breakdownRow(
                    label: "run.basePoints".localized,
                    value: String(format: "%.0f", result.basePoints),
                    tone: .neutral,
                    intensity: basePointsIntensity
                )
                breakdownRow(
                    label: "run.speedMultiplier".localized,
                    value: multiplierText(for: result.speedMultiplier),
                    tone: multiplierTone(for: result.speedMultiplier),
                    intensity: multiplierIntensity(for: result.speedMultiplier)
                )
                breakdownRow(
                    label: "run.durationMultiplier".localized,
                    value: multiplierText(for: result.durationMultiplier),
                    tone: multiplierTone(for: result.durationMultiplier),
                    intensity: multiplierIntensity(for: result.durationMultiplier)
                )
                breakdownRow(
                    label: "run.zoneMultiplier".localized,
                    value: multiplierText(for: result.zoneMultiplier),
                    tone: multiplierTone(for: result.zoneMultiplier),
                    intensity: multiplierIntensity(for: result.zoneMultiplier)
                )
                breakdownRow(
                    label: "run.streakMultiplier.label".localized,
                    value: multiplierText(for: result.streakMultiplier),
                    tone: multiplierTone(for: result.streakMultiplier),
                    intensity: multiplierIntensity(for: result.streakMultiplier)
                )

                if result.modeMultiplier > 1.0 {
                    breakdownRow(
                        label: "run.boostMultiplier".localized,
                        value: multiplierText(for: result.modeMultiplier, decimals: 1),
                        tone: multiplierTone(for: result.modeMultiplier, decimals: 1),
                        intensity: multiplierIntensity(for: result.modeMultiplier)
                    )
                }

                if result.antiFarmMultiplier < 1.0 {
                    breakdownRow(
                        label: "run.antiFarmMultiplier".localized,
                        value: multiplierText(for: result.antiFarmMultiplier),
                        tone: multiplierTone(for: result.antiFarmMultiplier),
                        intensity: multiplierIntensity(for: result.antiFarmMultiplier)
                    )
                }
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
        VStack(spacing: 10) {
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

            Button {
                onDismiss()
            } label: {
                Text("common.done".localized)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.isSaving)
        }
        .padding(.top, 4)
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

    private var basePointsIntensity: CGFloat {
        0.24
    }

    private var canShareSummary: Bool {
        viewModel.trailResult != nil && !viewModel.isSaving
    }

    private func multiplierText(for value: Double, decimals: Int = 2) -> String {
        String(format: "x%.\(decimals)f", roundedMultiplierValue(value, decimals: decimals))
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
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
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

    private func breakdownRow(
        label: String,
        value: String,
        tone: BreakdownTone,
        intensity: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tone.foreground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(tone.foreground.opacity(0.14))
                    )
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: tone.gradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(proxy.size.width * intensity, 28))
                }
            }
            .frame(height: 6)
        }
    }

    private func multiplierIntensity(for multiplier: Double) -> CGFloat {
        if multiplier < 1.0 {
            return CGFloat(0.14 + min(max(multiplier, 0), 1) * 0.18)
        }

        let positiveGain = min(multiplier - 1.0, 1.0)
        return CGFloat(0.24 + positiveGain * 0.42)
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

        let startAnnotation = MKPointAnnotation()
        startAnnotation.coordinate = coordinates.first!
        startAnnotation.title = "run.startPoint".localized

        let endAnnotation = MKPointAnnotation()
        endAnnotation.coordinate = coordinates.last!
        endAnnotation.title = "run.endPoint".localized

        mapView.addAnnotations([startAnnotation, endAnnotation])

        let rect = polyline.boundingMapRect
        let insets = UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)
        mapView.setVisibleMapRect(rect, edgePadding: insets, animated: false)
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
            return .territoryBlue
        }
    }

    var gradient: [Color] {
        switch self {
        case .positive:
            return [.boostGreen.opacity(0.85), .territoryBlue.opacity(0.72)]
        case .negative:
            return [.red.opacity(0.9), .orange.opacity(0.8)]
        case .neutral:
            return [.territoryBlue.opacity(0.85), .territoryBlue.opacity(0.45)]
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.territoryBlue.opacity(0.14))
                )

            Spacer(minLength: 0)

            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
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
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }
}
