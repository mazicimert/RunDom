import SwiftUI
import UIKit

struct OnboardingPageView: View {
    let media: OnboardingMedia
    let title: String
    let subtitle: String
    let supportingText: String
    let accentColor: Color
    let isActive: Bool

    @State private var hasAppeared = false

    // Phone-screen aspect ratio used to frame screenshots / video.
    private let phoneAspect: CGFloat = 9.0 / 19.5

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = min(max(proxy.size.height * 0.54, 310), 500)

            VStack(spacing: 22) {
                Spacer(minLength: 8)

                heroMedia(height: heroHeight)
                    .padding(.horizontal, 10)
                    .offset(x: isActive ? 0 : 22)
                    .opacity(isActive ? 1.0 : 0.82)
                    .animation(.easeInOut(duration: 0.32), value: isActive)

                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, AppConstants.UI.screenPadding)

                    Text(supportingText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, AppConstants.UI.screenPadding + 8)
                }
                .offset(y: hasAppeared ? 0 : 16)
                .opacity(hasAppeared ? 1.0 : 0)
                .animation(.easeInOut(duration: 0.3), value: hasAppeared)

                Spacer(minLength: 16)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .scaleEffect(hasAppeared ? 1.0 : 0.985)
            .opacity(hasAppeared ? 1.0 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.28)) {
                hasAppeared = true
            }
        }
        .onDisappear {
            hasAppeared = false
        }
    }

    // MARK: - Hero Media

    @ViewBuilder
    private func heroMedia(height: CGFloat) -> some View {
        ZStack {
            ambientGlow

            switch media {
            case let .video(resource, fileExtension):
                videoCard(resource: resource, fileExtension: fileExtension, height: height)
            case let .dualScreenshot(leading, trailing, topOverlay):
                dualScreenshot(
                    leading: leading,
                    trailing: trailing,
                    topOverlay: topOverlay,
                    height: height
                )
            }
        }
        .frame(height: height)
    }

    /// Soft, edgeless accent glow that bleeds into the page background so the
    /// devices appear to float — no boxed card boundary.
    private var ambientGlow: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.38))
                .frame(width: 280, height: 280)
                .blur(radius: 95)
                .offset(x: -46, y: -34)

            Circle()
                .fill(accentColor.opacity(0.22))
                .frame(width: 240, height: 240)
                .blur(radius: 90)
                .offset(x: 64, y: 56)
        }
    }

    // MARK: - Device Frame

    /// Wraps any content (screenshot or video) in an iPhone-style device frame:
    /// dark metallic bezel + rounded screen. The captured screenshots already
    /// include the status bar / Dynamic Island, so no notch is drawn here.
    @ViewBuilder
    private func deviceFrame<Content: View>(
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let bezel = max(width * 0.04, 5)
        let screenRadius = width * 0.14
        let outerRadius = screenRadius + bezel

        content()
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: screenRadius, style: .continuous))
            .padding(bezel)
            .background(
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.20), Color(white: 0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 10)
    }

    // MARK: - Video Card (Screen 1)

    @ViewBuilder
    private func videoCard(resource: String, fileExtension: String, height: CGFloat) -> some View {
        let cardHeight = height * 0.96
        let cardWidth = cardHeight * phoneAspect

        deviceFrame(width: cardWidth, height: cardHeight) {
            VideoLoopView(resourceName: resource, fileExtension: fileExtension)
        }
    }

    // MARK: - Dual Screenshot (Screens 2 & 3)

    private func dualScreenshot(
        leading: String,
        trailing: String,
        topOverlay: String?,
        height: CGFloat
    ) -> some View {
        // Identical phone size on both dual screens (2 & 3), matched to the
        // single video phone's height on Screen 1.
        let phoneHeight = height * 0.96
        let phoneWidth = phoneHeight * phoneAspect
        let bezel = max(phoneWidth * 0.04, 5)
        let framedWidth = phoneWidth + bezel * 2
        let overlap = phoneWidth * 0.20
        let phonesWidth = framedWidth * 2 - overlap

        // Bottom-align the phones so their base sits right above the title —
        // matching the single video phone's baseline on Screen 1.
        let bottomInset = height * 0.02

        // Banner sized from the (trimmed) PNG's real aspect ratio.
        let bannerWidth = phonesWidth * 0.94
        let bannerImage = topOverlay.flatMap { UIImage(named: $0) }
        let bannerHeight: CGFloat = bannerImage.map {
            bannerWidth * ($0.size.height / max($0.size.width, 1))
        } ?? 0

        // Sit the banner on the phones' status-bar strip. `statusBarBand` is
        // the knob: SMALLER → banner moves UP, LARGER → DOWN.
        let phoneTopInFrame = height - bottomInset - (phoneHeight + bezel * 2)
        let statusBarBand: CGFloat = 0.10
        let bannerTop = phoneTopInFrame + phoneHeight * statusBarBand - bannerHeight

        let phones = HStack(spacing: -overlap) {
            screenshotPhone(leading, width: phoneWidth, height: phoneHeight)
                .rotationEffect(.degrees(-6))
                .offset(y: 6)
                .zIndex(1)

            screenshotPhone(trailing, width: phoneWidth, height: phoneHeight)
                .rotationEffect(.degrees(6))
                .offset(y: -6)
        }

        return phones
            .padding(.bottom, bottomInset)
            .frame(maxWidth: .infinity)
            .frame(height: height, alignment: .bottom)
            // Place the banner on the phones' status bars without moving the
            // phones. `bannerTop` is computed from the phone top, so the offset
            // works regardless of device size.
            .overlay(alignment: .top) {
                if let bannerImage {
                    Image(uiImage: bannerImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: bannerWidth, height: bannerHeight)
                        .shadow(color: .black.opacity(0.55), radius: 16, x: 0, y: 10)
                        .offset(y: bannerTop)
                }
            }
    }

    private func screenshotPhone(_ name: String, width: CGFloat, height: CGFloat) -> some View {
        deviceFrame(width: width, height: height) {
            if let image = UIImage(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white.opacity(0.04), accentColor.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
            Image(systemName: "photo")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(accentColor)
        }
    }
}

#Preview {
    OnboardingPageView(
        media: .dualScreenshot(
            leading: "onboarding_map_overview",
            trailing: "onboarding_map_detail",
            topOverlay: "onboarding_attack_notification"
        ),
        title: "Claim & Defend",
        subtitle: "Tap any zone to see who owns it and how strong its defense is.",
        supportingText: "Lose a zone? You'll know — time to fight back.",
        accentColor: .green,
        isActive: true
    )
    .background(Color.black)
}
