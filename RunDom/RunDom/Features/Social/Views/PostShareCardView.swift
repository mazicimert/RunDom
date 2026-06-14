import SwiftUI
import UIKit
import FirebaseFirestore

enum PostShareTemplate: String, CaseIterable, Identifiable {
    case hero
    case card
    case stripe
    case mapOnly

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .hero: return "social.externalShare.template.hero".localized
        case .card: return "social.externalShare.template.card".localized
        case .stripe: return "social.externalShare.template.stripe".localized
        case .mapOnly: return "social.externalShare.template.mapOnly".localized
        }
    }
}

/// Renderable share card. All layout units are at native 1080×1920 —
/// scale down with scaleEffect for preview.
struct PostShareCardView: View {
    let post: Post
    let photoImage: UIImage?
    let template: PostShareTemplate

    private let canvasWidth: CGFloat = 1080
    private let canvasHeight: CGFloat = 1920

    private var accentColor: Color {
        Color(hex: post.authorColor) ?? .accentColor
    }

    /// Average pace (min per km/mi) derived from the run's average speed.
    private var paceValueText: String {
        guard post.avgSpeed > 0 else { return "--" }
        return "\(post.avgSpeed.formattedPace) \(UnitPreference.shared.paceUnitLabel)"
    }

    var body: some View {
        Group {
            switch template {
            case .hero: heroTemplate
            case .card: cardTemplate
            case .stripe: stripeTemplate
            case .mapOnly: mapOnlyTemplate
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .clipped()
    }

    // MARK: - Hero Template

    private var heroTemplate: some View {
        ZStack(alignment: .bottom) {
            backgroundFill
                .frame(width: canvasWidth, height: canvasHeight)
                .clipped()
            heroGradient
            heroStatsLayer
        }
        .overlay(alignment: .topTrailing) {
            pointsBadge(iconSize: 40, valueSize: 60, labelSize: 24, hPadding: 36, vPadding: 24)
                .padding(.top, 96)
                .padding(.trailing, 80)
        }
    }

    private var heroGradient: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.08), location: 0.40),
                .init(color: .black.opacity(0.65), location: 0.65),
                .init(color: .black.opacity(0.88), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: canvasWidth, height: canvasHeight)
    }

    private var heroStatsLayer: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 72) {
                heroMetricsRow
                brandRow(iconSize: 60, textSize: 48, textColor: .white)
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 110)
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }

    private var heroMetricsRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            heroMetricItem(
                icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                value: post.distance.formattedDistanceFromMeters,
                label: "run.distance".localized,
                tint: .white
            )
            verticalDivider(height: 88, opacity: 0.22, hPadding: 42)
            heroMetricItem(
                icon: "clock.fill",
                value: formatDuration(post.duration),
                label: "run.duration".localized,
                tint: .white
            )
            verticalDivider(height: 88, opacity: 0.22, hPadding: 42)
            heroMetricItem(
                icon: "stopwatch.fill",
                value: paceValueText,
                label: "run.pace".localized,
                tint: .white
            )
        }
    }

    private func heroMetricItem(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(tint.opacity(0.85))
            Text(value)
                .font(.system(size: 68, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .textCase(.uppercase)
                .tracking(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Card Template (polaroid style)

    private var cardTemplate: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.13),
                    Color(red: 0.02, green: 0.03, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Photo panel (top of polaroid) — fills polaroid width × 1000pt
                backgroundFill
                    .frame(width: canvasWidth - 80, height: 1000)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        pointsBadge(iconSize: 38, valueSize: 56, labelSize: 22, hPadding: 32, vPadding: 22)
                            .padding(.top, 40)
                            .padding(.trailing, 40)
                    }

                // Stats panel (bottom of polaroid) — content vertically centered
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 44) {
                        cardStatsGrid
                        brandRow(iconSize: 56, textSize: 44, textColor: .white)
                    }
                    .padding(.horizontal, 60)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.04, green: 0.05, blue: 0.10))
            }
            .frame(width: canvasWidth - 80, height: canvasHeight - 160)
            .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }

    private var cardStatsGrid: some View {
        HStack(alignment: .top, spacing: 0) {
            cardStatItem(
                value: post.distance.formattedDistanceFromMeters,
                label: "run.distance".localized,
                accent: false
            )
            verticalDivider(height: 96, opacity: 0.16, hPadding: 28)
            cardStatItem(
                value: formatDuration(post.duration),
                label: "run.duration".localized,
                accent: false
            )
            verticalDivider(height: 96, opacity: 0.16, hPadding: 28)
            cardStatItem(
                value: paceValueText,
                label: "run.pace".localized,
                accent: false
            )
        }
    }

    private func cardStatItem(value: String, label: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(value)
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundStyle(accent ? accentColor : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stripe Template

    private var stripeTemplate: some View {
        ZStack(alignment: .bottom) {
            backgroundFill
                .frame(width: canvasWidth, height: canvasHeight)
                .clipped()
            stripeBar
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .overlay(alignment: .topTrailing) {
            pointsBadge(iconSize: 38, valueSize: 56, labelSize: 22, hPadding: 32, vPadding: 22)
                .padding(.top, 96)
                .padding(.trailing, 60)
        }
    }

    private var stripeBar: some View {
        VStack(spacing: 36) {
            HStack(spacing: 0) {
                stripeStat(
                    value: post.distance.formattedDistanceFromMeters,
                    label: "run.distance".localized
                )
                verticalDivider(height: 80, opacity: 0.35, hPadding: 24)
                stripeStat(
                    value: formatDuration(post.duration),
                    label: "run.duration".localized
                )
                verticalDivider(height: 80, opacity: 0.35, hPadding: 24)
                stripeStat(
                    value: paceValueText,
                    label: "run.pace".localized
                )
            }
            brandRow(iconSize: 46, textSize: 36, textColor: .white)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 64)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [accentColor.opacity(0.92), accentColor],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private func stripeStat(value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .textCase(.uppercase)
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Map Only Template

    private var mapOnlyTemplate: some View {
        backgroundFill
            .frame(width: canvasWidth, height: canvasHeight)
            .clipped()
    }

    // MARK: - Shared building blocks

    /// Size-flexible background — each template wraps in its own frame.
    /// CRITICAL: do NOT hardcode width/height here; the Card template uses
    /// a smaller photo panel than the canvas, and forcing 1080×1920 inside
    /// a 1000×1000 parent triggers expensive layout reflows on every state
    /// change, freezing the preview when the photo or template switches.
    @ViewBuilder
    private var backgroundFill: some View {
        if let photo = photoImage {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.75),
                        accentColor.opacity(0.35),
                        Color.black.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "figure.run")
                    .font(.system(size: 340, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.08))
            }
        }
    }

    private func verticalDivider(height: CGFloat, opacity: Double, hPadding: CGFloat) -> some View {
        Rectangle()
            .fill(.white.opacity(opacity))
            .frame(width: 2, height: height)
            .padding(.horizontal, hPadding)
    }

    /// Highlighted Points badge anchored to the top-right of each template.
    /// Uses the user's accent color so it carries the run's identity colour
    /// and stays legible over arbitrary photo backgrounds.
    private func pointsBadge(iconSize: CGFloat, valueSize: CGFloat, labelSize: CGFloat, hPadding: CGFloat, vPadding: CGFloat) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(post.trail.formattedTrail)
                    .font(.system(size: valueSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .monospacedDigit()
                Text("trail.unit".localized)
                    .font(.system(size: labelSize, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(1.5)
            }
        }
        .padding(.horizontal, hPadding)
        .padding(.vertical, vPadding)
        .background(
            Capsule(style: .continuous)
                .fill(accentColor)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 8)
        )
    }

    private func brandRow(iconSize: CGFloat, textSize: CGFloat, textColor: Color) -> some View {
        HStack(spacing: 20) {
            Image("logo")
                .resizable()
                .scaledToFill()
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.23, style: .continuous))
            Text("Runpire")
                .font(.system(size: textSize, weight: .black))
                .foregroundStyle(textColor)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

#if DEBUG
private struct PostShareCardPreview: View {
    let post: Post
    let photo: UIImage?
    let template: PostShareTemplate
    private let displayWidth: CGFloat = 320
    private var displayHeight: CGFloat { displayWidth * 1920 / 1080 }
    private var scale: CGFloat { displayWidth / 1080 }

    var body: some View {
        Color.clear
            .frame(width: displayWidth, height: displayHeight)
            .overlay(alignment: .topLeading) {
                PostShareCardView(post: post, photoImage: photo, template: template)
                    .frame(width: 1080, height: 1920)
                    .scaleEffect(scale, anchor: .topLeading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension Post {
    static let preview = Post(
        id: "preview", authorId: "u1", authorDisplayName: "Mert Mazıcı",
        authorPhotoURL: nil, authorColor: "#4ECDC4", runId: "r1",
        createdAt: .now, distance: 8_350, duration: 3_180, avgSpeed: 9.4,
        trail: 842, startDate: .now, tags: [], note: nil,
        routePreview: [
            GeoPoint(latitude: 41.015, longitude: 28.979),
            GeoPoint(latitude: 41.020, longitude: 28.984),
            GeoPoint(latitude: 41.018, longitude: 28.992),
            GeoPoint(latitude: 41.012, longitude: 28.996)
        ],
        shareCardImageURL: nil, photoURLs: nil
    )
}

#Preview("Hero") {
    PostShareCardPreview(post: .preview, photo: nil, template: .hero)
        .padding()
}

#Preview("Card") {
    PostShareCardPreview(post: .preview, photo: nil, template: .card)
        .padding()
}

#Preview("Stripe") {
    PostShareCardPreview(post: .preview, photo: nil, template: .stripe)
        .padding()
}

#Preview("Map Only") {
    PostShareCardPreview(post: .preview, photo: nil, template: .mapOnly)
        .padding()
}
#endif
