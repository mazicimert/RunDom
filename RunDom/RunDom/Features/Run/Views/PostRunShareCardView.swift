import SwiftUI

struct PostRunShareCardView: View {
    let session: RunSession
    let trailText: String
    let modeText: String
    let performanceText: String
    let subtitleText: String
    let avgSpeedText: String
    let brandText: String
    let dateText: String
    let canvasSize: CGSize

    private let cardGradient = LinearGradient(
        colors: [
            Color(red: 0.07, green: 0.1, blue: 0.19),
            Color(red: 0.04, green: 0.06, blue: 0.12),
            Color(red: 0.02, green: 0.03, blue: 0.07)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private var outerPadding: CGFloat {
        min(max(canvasSize.width * 0.05, 16), 22)
    }

    private var cardPadding: CGFloat {
        canvasSize.height > 760 ? 24 : 22
    }

    private var sectionSpacing: CGFloat {
        canvasSize.height > 760 ? 20 : 16
    }

    private var routeHeight: CGFloat {
        if session.trail <= 0 {
            return min(max(canvasSize.height * 0.18, 148), 180)
        }

        return min(max(canvasSize.height * 0.2, 156), 204)
    }

    private var scoreFontSize: CGFloat {
        min(max(canvasSize.width * 0.23, 80), 94)
    }

    private var metricsColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10, alignment: .top),
            GridItem(.flexible(), spacing: 10, alignment: .top),
            GridItem(.flexible(), spacing: 10, alignment: .top)
        ]
    }

    private var statCards: [ShareMetricItem] {
        [
            ShareMetricItem(icon: "ruler", text: session.distance.formattedDistanceFromMeters, tint: .territoryBlue, title: "run.distance".localized),
            ShareMetricItem(icon: "clock", text: durationText, tint: .white, title: "run.duration".localized),
            ShareMetricItem(icon: "speedometer", text: avgSpeedText, tint: .boostGreen, title: "run.avgSpeed".localized)
        ]
    }

    var body: some View {
        ZStack {
            shareBackground

            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(cardGradient)
                .overlay(cardOutline)
                .overlay(cardGlow)
                .padding(outerPadding)
                .overlay(alignment: .topLeading) {
                    cardContent
                        .padding(outerPadding + cardPadding)
                }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipped()
    }

    private var shareBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.11),
                    Color(red: 0.01, green: 0.02, blue: 0.06),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.territoryBlue.opacity(0.26))
                .frame(width: canvasSize.width * 0.74, height: canvasSize.width * 0.74)
                .blur(radius: 72)
                .offset(x: -canvasSize.width * 0.2, y: -canvasSize.height * 0.28)

            Circle()
                .fill(Color.boostGreen.opacity(0.16))
                .frame(width: canvasSize.width * 0.54, height: canvasSize.width * 0.54)
                .blur(radius: 88)
                .offset(x: canvasSize.width * 0.28, y: canvasSize.height * 0.32)
        }
    }

    private var cardOutline: some View {
        RoundedRectangle(cornerRadius: 38, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var cardGlow: some View {
        RoundedRectangle(cornerRadius: 38, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.04), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            )
            .padding(1)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            header
            scoreSection
            routeSection
            metricsSection
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.territoryBlue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(brandText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    Text("run.summary".localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))

                    Text(dateText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            Text(modeText)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
    }

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(performanceText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(trailText)
                .font(.system(size: scoreFontSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()

            Text("run.trailEarned".localized)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))

            Text(subtitleText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("run.summary.route".localized)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 14) {
                AbstractRunRouteView(routePoints: session.route)
                    .frame(height: routeHeight)
            }
            .padding(18)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var metricsSection: some View {
        LazyVGrid(columns: metricsColumns, alignment: .leading, spacing: 12) {
            ForEach(statCards) { stat in
                shareStatCard(title: stat.title ?? "", value: stat.text, icon: stat.icon, tint: stat.tint)
            }
        }
    }

    private func shareStatCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.14))
                )

            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var durationText: String {
        session.duration.formattedDuration
    }
}

private struct ShareMetricItem: Identifiable {
    let icon: String
    let text: String
    let tint: Color
    var title: String?

    var id: String {
        "\(icon)-\(title ?? text)"
    }
}

private struct AbstractRunRouteView: View {
    let routePoints: [RoutePoint]

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if points.count >= 2 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [Color.territoryBlue, Color.boostGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round)
                    )

                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.territoryBlue, lineWidth: 5))
                        .position(points.first ?? .zero)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.boostGreen, lineWidth: 5))
                        .position(points.last ?? .zero)
                } else {
                    VStack(spacing: 12) {
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: proxy.size.width * 0.56, height: 10)
                        Text("run.summary.performance.saved".localized)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard routePoints.count >= 2 else { return [] }

        let latitudes = routePoints.map(\.latitude)
        let longitudes = routePoints.map(\.longitude)

        guard let minLatitude = latitudes.min(),
              let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(),
              let maxLongitude = longitudes.max() else {
            return []
        }

        let latSpan = max(maxLatitude - minLatitude, 0.00001)
        let lonSpan = max(maxLongitude - minLongitude, 0.00001)

        let insetRect = CGRect(x: 24, y: 20, width: size.width - 48, height: size.height - 40)
        let scale = min(insetRect.width / lonSpan, insetRect.height / latSpan)
        let drawWidth = lonSpan * scale
        let drawHeight = latSpan * scale
        let xOffset = insetRect.minX + (insetRect.width - drawWidth) / 2
        let yOffset = insetRect.minY + (insetRect.height - drawHeight) / 2

        return routePoints.map { point in
            let x = xOffset + ((point.longitude - minLongitude) * scale)
            let normalizedY = (point.latitude - minLatitude) * scale
            let y = yOffset + (drawHeight - normalizedY)
            return CGPoint(x: x, y: y)
        }
    }
}

private struct ShareCardPreviewContainer: View {
    let title: String
    let languageCode: String
    let session: RunSession
    let trailText: String
    let modeText: String
    let performanceText: String
    let subtitleText: String
    let avgSpeedText: String
    let dateText: String
    let canvasSize: CGSize

    var body: some View {
        PostRunShareCardView(
            session: session,
            trailText: trailText,
            modeText: modeText,
            performanceText: performanceText,
            subtitleText: subtitleText,
            avgSpeedText: avgSpeedText,
            brandText: "Runpire",
            dateText: dateText,
            canvasSize: canvasSize
        )
        .onAppear {
            LocalizationManager.shared.selectedLanguageCode = languageCode
        }
        .previewDisplayName(title)
    }
}

#Preview("TR Short Run") {
    ShareCardPreviewContainer(
        title: "TR Short Run",
        languageCode: "tr",
        session: .sharePreviewShort,
        trailText: "3",
        modeText: "Normal Mod",
        performanceText: "2 bölge ele geçirildi",
        subtitleText: "0,05 km mesafeyi 00:11 içinde tamamladın",
        avgSpeedText: "4,5 km/h",
        dateText: "25 Mar 2026 • 18:42",
        canvasSize: CGSize(width: 390, height: 844)
    )
}

#Preview("TR Long Run") {
    ShareCardPreviewContainer(
        title: "TR Long Run",
        languageCode: "tr",
        session: .sharePreviewLong,
        trailText: "1.248",
        modeText: "Boost Aktif",
        performanceText: "12 bölge ele geçirildi",
        subtitleText: "12,48 km mesafeyi 01:24:32 içinde tamamladın",
        avgSpeedText: "8,9 km/h",
        dateText: "25 Mar 2026 • 06:10",
        canvasSize: CGSize(width: 390, height: 844)
    )
}

#Preview("EN Long Copy") {
    ShareCardPreviewContainer(
        title: "EN Long Copy",
        languageCode: "en",
        session: .sharePreviewLong,
        trailText: "1,248",
        modeText: "Boost Active",
        performanceText: "12 territories captured",
        subtitleText: "You covered 12.48 km in 1:24:32",
        avgSpeedText: "8.9 km/h",
        dateText: "Mar 25, 2026 • 6:10 AM",
        canvasSize: CGSize(width: 390, height: 844)
    )
}

#Preview("TR No Territories") {
    ShareCardPreviewContainer(
        title: "TR No Territories",
        languageCode: "tr",
        session: .sharePreviewNoTerritories,
        trailText: "0",
        modeText: "Normal Mod",
        performanceText: "Koşun kaydedildi",
        subtitleText: "Bugünkü limite ulaştığın için bu koşudan puan alamadın.",
        avgSpeedText: "6,2 km/h",
        dateText: "25 Mar 2026 • 21:05",
        canvasSize: CGSize(width: 390, height: 844)
    )
}

private extension RunSession {
    static let sharePreviewShort = RunSession(
        id: "preview-short",
        userId: "preview",
        mode: .normal,
        startDate: Date(timeIntervalSince1970: 1_742_918_520),
        endDate: Date(timeIntervalSince1970: 1_742_918_531),
        distance: 50,
        avgSpeed: 4.5,
        maxSpeed: 6.0,
        trail: 3,
        territoriesCaptured: 2,
        uniqueZonesVisited: 2,
        totalZonesVisited: 2,
        route: [
            RoutePoint(latitude: 41.015, longitude: 28.979, timestamp: Date(), speed: 1.2, altitude: 12),
            RoutePoint(latitude: 41.0142, longitude: 28.9825, timestamp: Date(), speed: 1.3, altitude: 11)
        ],
        isBoostActive: true,
        seasonId: nil
    )

    static let sharePreviewLong = RunSession(
        id: "preview-long",
        userId: "preview",
        mode: .boost,
        startDate: Date(timeIntervalSince1970: 1_742_873_400),
        endDate: Date(timeIntervalSince1970: 1_742_878_472),
        distance: 12_480,
        avgSpeed: 8.9,
        maxSpeed: 12.8,
        trail: 1_248,
        territoriesCaptured: 12,
        uniqueZonesVisited: 15,
        totalZonesVisited: 18,
        route: [
            RoutePoint(latitude: 41.036, longitude: 29.004, timestamp: Date(), speed: 2.4, altitude: 35),
            RoutePoint(latitude: 41.031, longitude: 29.008, timestamp: Date(), speed: 2.8, altitude: 44),
            RoutePoint(latitude: 41.025, longitude: 29.013, timestamp: Date(), speed: 2.7, altitude: 40),
            RoutePoint(latitude: 41.021, longitude: 29.021, timestamp: Date(), speed: 2.9, altitude: 26)
        ],
        isBoostActive: true,
        seasonId: nil
    )

    static let sharePreviewNoTerritories = RunSession(
        id: "preview-zero",
        userId: "preview",
        mode: .normal,
        startDate: Date(timeIntervalSince1970: 1_742_927_500),
        endDate: Date(timeIntervalSince1970: 1_742_929_000),
        distance: 2_580,
        avgSpeed: 6.2,
        maxSpeed: 8.0,
        trail: 0,
        territoriesCaptured: 0,
        uniqueZonesVisited: 4,
        totalZonesVisited: 6,
        route: [
            RoutePoint(latitude: 41.002, longitude: 28.971, timestamp: Date(), speed: 1.9, altitude: 18),
            RoutePoint(latitude: 41.004, longitude: 28.974, timestamp: Date(), speed: 1.7, altitude: 19),
            RoutePoint(latitude: 41.007, longitude: 28.978, timestamp: Date(), speed: 1.8, altitude: 22)
        ],
        isBoostActive: true,
        seasonId: nil
    )
}
