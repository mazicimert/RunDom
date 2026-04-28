import SwiftUI
import UIKit

struct OnboardingPageView: View {
    let mediaAssetName: String
    let mediaStyle: OnboardingMediaStyle
    let title: String
    let subtitle: String
    let supportingText: String
    let accentColor: Color
    let isActive: Bool

    @State private var hasAppeared = false

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = min(max(proxy.size.height * 0.42, 250), 370)

            VStack(spacing: 22) {
                Spacer(minLength: 8)

                heroMedia(height: heroHeight)
                    .padding(.horizontal, AppConstants.UI.screenPadding)
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

    @ViewBuilder
    private func heroMedia(height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.28),
                            accentColor.opacity(0.08),
                            Color.black.opacity(0.65)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(accentColor.opacity(0.26))
                        .frame(width: 108, height: 108)
                        .blur(radius: 18)
                        .offset(x: 28, y: -28)
                }
                .overlay(alignment: .bottomLeading) {
                    Circle()
                        .fill(accentColor.opacity(0.22))
                        .frame(width: 92, height: 92)
                        .blur(radius: 20)
                        .offset(x: -18, y: 20)
                }

            if mediaStyle == .screenshotCard {
                screenshotMockCard(height: height - 30)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 15)
            } else {
                iconAccentCard
                    .padding(.horizontal, 14)
                    .padding(.vertical, 15)
            }
        }
        .frame(height: height)
        .shadow(color: accentColor.opacity(0.16), radius: 22, x: 0, y: 14)
    }

    @ViewBuilder
    private func screenshotMockCard(height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.9))

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
                .padding(4)

            mediaContent
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(10)
        }
        .frame(height: height)
        .overlay(alignment: .top) {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.18))
                .frame(width: 78, height: 6)
                .padding(.top, 10)
        }
    }

    @ViewBuilder
    private var mediaContent: some View {
        if let image = UIImage(named: mediaAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color.white.opacity(0.03), accentColor.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 10) {
                    Image(systemName: placeholderIconName)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(accentColor)

                    Text("onboarding.placeholder".localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
    }

    private var iconAccentCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.04))

            Image(systemName: placeholderIconName)
                .font(.system(size: 92, weight: .black))
                .foregroundStyle(accentColor)
        }
    }

    private var placeholderIconName: String {
        switch mediaAssetName {
        case "onboarding_map_mock":
            return "map.fill"
        case "onboarding_run_mock":
            return "figure.run"
        case "onboarding_stats_mock":
            return "chart.bar.fill"
        case "onboarding_start_mock":
            return "sparkles"
        default:
            return "photo"
        }
    }
}

#Preview {
    OnboardingPageView(
        mediaAssetName: "onboarding_map_mock",
        mediaStyle: .screenshotCard,
        title: "Şehrini Fethet",
        subtitle: "Haritada gerçek bölgeleri gör, koşarak alanları kendi renginle kapla.",
        supportingText: "Harita ekranı canlı olarak sahiplik durumunu gösterir.",
        accentColor: .blue,
        isActive: true
    )
}
