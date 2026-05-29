import SwiftUI
import UIKit
import FirebaseFirestore

enum PostShareTemplate: String, CaseIterable, Identifiable {
    case hero
    case card
    case stripe

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .hero: return "social.externalShare.template.hero".localized
        case .card: return "social.externalShare.template.card".localized
        case .stripe: return "social.externalShare.template.stripe".localized
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

    var body: some View {
        Group {
            switch template {
            case .hero: heroTemplate
            case .card: cardTemplate
            case .stripe: stripeTemplate
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
                icon: "flame.fill",
                value: post.trail.formattedTrail,
                label: "trail.unit".localized,
                tint: accentColor
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

                // Stats panel (bottom of polaroid) — content vertically centered
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 44) {
                        cardStatsGrid
                        cardRouteSection
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
                value: post.trail.formattedTrail,
                label: "trail.unit".localized,
                accent: true
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

    private var cardRouteSection: some View {
        HStack(spacing: 28) {
            RouteMiniView(
                routePreview: post.routePreview,
                strokeColor: accentColor
            )
            .frame(width: 280, height: 160)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("run.summary.route".localized)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1.5)
                if post.avgSpeed > 0 {
                    Text(String(format: "%.1f", post.avgSpeed) + " " + "unit.speed.kmh".localized)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                    Text("run.avgSpeed".localized)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            Spacer(minLength: 0)
        }
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
                    value: post.trail.formattedTrail,
                    label: "trail.unit".localized
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

// MARK: - Route mini (used by Card template)

private struct RouteMiniView: View {
    let routePreview: [GeoPoint]
    let strokeColor: Color

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)

            if points.count >= 2 {
                ZStack {
                    Path { path in
                        path.move(to: points[0])
                        for p in points.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(
                        strokeColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )

                    if let first = points.first {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(strokeColor, lineWidth: 3))
                            .position(first)
                    }
                    if let last = points.last {
                        Circle()
                            .fill(strokeColor)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .position(last)
                    }
                }
            } else {
                Image(systemName: "map")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white.opacity(0.25))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard routePreview.count >= 2 else { return [] }
        let latitudes = routePreview.map(\.latitude)
        let longitudes = routePreview.map(\.longitude)
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else {
            return []
        }
        let latSpan = max(maxLat - minLat, 0.00001)
        let lonSpan = max(maxLon - minLon, 0.00001)
        let inset: CGFloat = 18
        let rect = CGRect(x: inset, y: inset, width: size.width - 2*inset, height: size.height - 2*inset)
        let scale = min(rect.width / lonSpan, rect.height / latSpan)
        let drawW = lonSpan * scale
        let drawH = latSpan * scale
        let xOff = rect.minX + (rect.width - drawW) / 2
        let yOff = rect.minY + (rect.height - drawH) / 2
        return routePreview.map { p in
            let x = xOff + ((p.longitude - minLon) * scale)
            let y = yOff + (drawH - (p.latitude - minLat) * scale)
            return CGPoint(x: x, y: y)
        }
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
#endif
