import CoreLocation
import Foundation
import SwiftUI

struct LocationPrimingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onAllow: () -> Void
    let onSkip: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var routeProgress: CGFloat = 0
    @State private var pulseExpanded = false
    @State private var contentVisible = false

    private static let routeFrameSize: CGFloat = 200

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                heroVisual
                    .frame(height: 280)

                Spacer().frame(height: 24)

                VStack(spacing: 12) {
                    Text(titleKey.localized)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(subtitleKey.localized)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .opacity(contentVisible ? 1 : 0)

                bullets
                    .padding(.horizontal, AppConstants.UI.screenPadding)
                    .padding(.top, 24)
                    .opacity(contentVisible ? 1 : 0)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        onAllow()
                    } label: {
                        Text(ctaKey.localized)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if canContinueWithoutOpeningPermissionPrompt {
                        Button {
                            onSkip()
                        } label: {
                            Text("onboarding.location.skip".localized)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.55))
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.bottom, 32)
                .opacity(contentVisible ? 1 : 0)
            }
        }
        .onAppear { animateIn() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.reevaluateLocationStatusOnReturn()
            }
        }
    }

    /// CTA / copy adapt to the current iOS auth state.
    /// - notDetermined: neutral "Continue" → triggers system prompt
    /// - denied/restricted: "Open iOS Settings" → deep links (system can't re-prompt)
    /// - authorized: handled by ViewModel by skipping this step entirely
    private var titleKey: String {
        switch viewModel.locationAuthStatus {
        case .denied, .restricted:
            return "onboarding.location.deniedTitle"
        default:
            return "onboarding.location.title"
        }
    }

    private var subtitleKey: String {
        switch viewModel.locationAuthStatus {
        case .denied, .restricted:
            return "onboarding.location.deniedSubtitle"
        default:
            return "onboarding.location.subtitle"
        }
    }

    private var ctaKey: String {
        switch viewModel.locationAuthStatus {
        case .denied, .restricted:
            return "onboarding.location.openSettings"
        default:
            return "onboarding.location.allow"
        }
    }

    /// Apple's pre-alert guidance requires a single neutral action that always
    /// opens the system permission prompt. A secondary action is only shown
    /// after iOS has already denied or restricted access and can't re-prompt.
    private var canContinueWithoutOpeningPermissionPrompt: Bool {
        switch viewModel.locationAuthStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    // MARK: - Derived

    private var routeColor: Color {
        Color(hex: viewModel.pendingColor) ?? Color.accentColor
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.04, green: 0.08, blue: 0.16),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            routeColor
                .opacity(0.16)
                .blur(radius: 80)
                .frame(width: 320, height: 320)
                .offset(y: -200)
                .animation(.easeInOut(duration: 0.4), value: viewModel.pendingColor)
        }
    }

    // MARK: - Hero

    private var heroVisual: some View {
        ZStack {
            // Decorative hex rings
            ForEach(0..<4, id: \.self) { index in
                LocationHexShape()
                    .stroke(Color.white.opacity(Double(4 - index) * 0.05), lineWidth: 1)
                    .frame(
                        width: 240 + CGFloat(index) * 28,
                        height: 240 + CGFloat(index) * 28
                    )
            }

            // The "map" hex
            LocationHexShape()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 240, height: 240)

            LocationHexShape()
                .stroke(Color.white.opacity(0.14), lineWidth: 1.5)
                .frame(width: 240, height: 240)

            // Route + GPS dot — both share the same coord space
            ZStack {
                RoutePath()
                    .trim(from: 0, to: routeProgress)
                    .stroke(
                        routeColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: routeColor.opacity(0.6), radius: 6)

                // Start dot
                Circle()
                    .fill(Color.black)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(routeColor, lineWidth: 2.5))
                    .position(routeStart)

                // GPS dot at end (appears once route is drawn)
                if routeProgress >= 0.95 {
                    ZStack {
                        Circle()
                            .stroke(routeColor.opacity(0.6), lineWidth: 2)
                            .frame(width: pulseExpanded ? 38 : 14, height: pulseExpanded ? 38 : 14)
                            .opacity(pulseExpanded ? 0 : 0.7)

                        Circle()
                            .fill(routeColor)
                            .frame(width: 14, height: 14)
                            .shadow(color: routeColor, radius: 6)
                    }
                    .position(routeEnd)
                }
            }
            .frame(width: Self.routeFrameSize, height: Self.routeFrameSize)
        }
    }

    private var routeStart: CGPoint {
        CGPoint(x: Self.routeFrameSize * 0.16, y: Self.routeFrameSize * 0.78)
    }

    private var routeEnd: CGPoint {
        CGPoint(x: Self.routeFrameSize * 0.84, y: Self.routeFrameSize * 0.30)
    }

    // MARK: - Bullets

    private var bullets: some View {
        VStack(alignment: .leading, spacing: 12) {
            BulletRow(icon: "figure.run", text: "onboarding.location.bullet1".localized)
            BulletRow(icon: "lock.shield.fill", text: "onboarding.location.bullet2".localized)
            BulletRow(icon: "flag.checkered", text: "onboarding.location.bullet3".localized)
        }
    }

    // MARK: - Animation

    private func animateIn() {
        AnalyticsService.logOnboardingLocationPrimeShown()

        withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
            contentVisible = true
        }
        withAnimation(.easeInOut(duration: 1.8).delay(0.4)) {
            routeProgress = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulseExpanded = true
            }
        }
    }
}

// MARK: - Bullet Row

private struct BulletRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.08)))

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// MARK: - Hex Shape

private struct LocationHexShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let angle = (Double(i) * 60.0 - 30.0) * .pi / 180.0
            let point = CGPoint(
                x: center.x + radius * CGFloat(Foundation.cos(angle)),
                y: center.y + radius * CGFloat(Foundation.sin(angle))
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Route Path (a stylized winding run route)

private struct RoutePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.16, y: h * 0.78))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.40, y: h * 0.55),
            control: CGPoint(x: w * 0.18, y: h * 0.55)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.62, y: h * 0.66),
            control: CGPoint(x: w * 0.55, y: h * 0.80)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.84, y: h * 0.30),
            control: CGPoint(x: w * 0.86, y: h * 0.55)
        )
        return path
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.pendingColor = "#4ECDC4"
    return LocationPrimingView(
        viewModel: vm,
        onAllow: {},
        onSkip: {}
    )
}
