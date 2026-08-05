import SwiftUI

struct TerritoryConquestView: View {
    let userColor: Color
    let opponentColor: Color
    let comboCount: Int
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isVisible = false
    @State private var isCracked = false
    @State private var isShattered = false
    @State private var isConquered = false
    @State private var showSatellites = false
    @State private var showDetails = false
    @State private var isExiting = false
    @State private var shakeOffset: CGFloat = 0
    @State private var crackProgress: CGFloat = 0
    @State private var flashOpacity: Double = 0
    @State private var flashScale: CGFloat = 0.9
    @State private var defenseTransferProgress: CGFloat = 0
    @State private var sparkProgress: CGFloat = 0
    @State private var tileImpactScale: CGFloat = 1

    private let hexSize: CGFloat = 174

    var body: some View {
        ZStack {
            Color.black
                .opacity(isVisible ? 0.34 : 0)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    (isConquered ? userColor : opponentColor).opacity(isConquered ? 0.26 : 0.14),
                    .clear
                ],
                center: .center,
                startRadius: 8,
                endRadius: 240
            )
            .scaleEffect(isConquered ? 1.18 : 0.74)
            .opacity(isVisible ? 1 : 0)

            defenseTransferTrail

            GeometryReader { proxy in
                let baseLift = min(max(proxy.size.height * 0.065, 44), 64)
                let comboLift: CGFloat = comboCount > 1 ? 32 : 0
                let verticalLift = baseLift + comboLift

                VStack(spacing: 22) {
                    ZStack {
                        comboHexagons

                        energyRing

                        // The prize sits underneath the opponent's tile the whole time and
                        // is simply uncovered when the shards fly off.
                        conqueredHexagon

                        // The opponent's tile is built from the six shards themselves, so
                        // the break is the tile coming apart rather than a colour swap.
                        opponentTile

                        sparkBurst
                        impactFlash
                    }
                    .frame(width: 300, height: 268)

                    conquestCopy
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: -verticalLift)
            }
            .scaleEffect(isExiting ? 0.82 : (isVisible ? 1 : 0.72))
            .opacity(isExiting ? 0 : (isVisible ? 1 : 0))
            .offset(x: shakeOffset)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .task {
            await playAnimation()
        }
    }

    // MARK: - Opponent tile (shatters)

    private var opponentTile: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                shard(at: index)
            }

            ConquestHexagon()
                .stroke(.white.opacity(0.5), lineWidth: 1.5)
                .frame(width: hexSize, height: hexSize)
                .opacity(isShattered ? 0 : 1)
                .animation(.easeOut(duration: 0.14), value: isShattered)

            cracks
        }
        .shadow(color: opponentColor.opacity(isShattered ? 0 : 0.4), radius: 16, y: 8)
        .scaleEffect(tileImpactScale)
    }

    /// One of the six wedges the opponent's hexagon is made of. At rest they tile the
    /// hexagon seamlessly; on the break they spin and fly apart along their own bisector.
    private func shard(at index: Int) -> some View {
        let direction = shardDirection(index)
        let spin: Double = index.isMultiple(of: 2) ? 38 : -32

        return ConquestShard(index: index)
            .fill(
                LinearGradient(
                    colors: [
                        opponentColor.opacity(0.98),
                        opponentColor.opacity(0.66),
                        Color.black.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                // Seams stay invisible until the fracture, then light up so the tile
                // reads as already broken before it actually separates.
                ConquestShard(index: index)
                    .stroke(.white.opacity(isCracked ? 0.9 : 0), lineWidth: 1.4)
                    .animation(.easeOut(duration: 0.24), value: isCracked)
            }
            .frame(width: hexSize, height: hexSize)
            .rotationEffect(.degrees(isShattered ? spin : 0))
            .scaleEffect(isShattered ? 0.66 : 1)
            .offset(
                x: direction.width * (isShattered ? 168 : 0),
                y: direction.height * (isShattered ? 150 : 0)
            )
            .animation(
                .easeOut(duration: 0.62).delay(Double(index) * 0.022),
                value: isShattered
            )
            .opacity(isShattered ? 0 : 1)
            // Held opaque through the first half of the flight so the pieces are
            // genuinely readable instead of dissolving the moment they move, then
            // cleared before the copy fades in underneath them.
            .animation(.easeIn(duration: 0.28).delay(0.22), value: isShattered)
    }

    private func shardDirection(_ index: Int) -> CGSize {
        let angle = (Double(index) * .pi / 3) - (.pi / 2) + (.pi / 6)
        return CGSize(width: CGFloat(cos(angle)), height: CGFloat(sin(angle)))
    }

    private var cracks: some View {
        ZStack {
            // Wide soft pass first: gives the fracture a glow so it survives against
            // the opponent's saturated fill instead of reading as a hairline.
            ConquestCracks()
                .trim(from: 0, to: crackProgress)
                .stroke(
                    Color.white.opacity(0.45),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 6)

            ConquestCracks()
                .trim(from: 0, to: crackProgress)
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
        }
        .padding(16)
        .frame(width: hexSize, height: hexSize)
        .opacity(isShattered ? 0 : 1)
        .animation(.easeOut(duration: 0.16), value: isShattered)
    }

    // MARK: - Conquered tile (revealed)

    private var conqueredHexagon: some View {
        ZStack {
            ConquestHexagon()
                .fill(
                    LinearGradient(
                        colors: [
                            userColor.opacity(0.72),
                            userColor,
                            userColor.opacity(0.72)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
                .overlay {
                    LinearGradient(
                        colors: [.white.opacity(0.38), .clear, .black.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(ConquestHexagon())
                }

            ConquestHexagon()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.92), userColor.opacity(0.9), .white.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )

            if isConquered {
                VStack(spacing: 0) {
                    Text("+1")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .monospacedDigit()

                    Image(systemName: "flag.checkered.2.crossed")
                        .font(.system(size: 19, weight: .bold))
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
                .transition(.scale(scale: 0.55).combined(with: .opacity))
            }
        }
        .frame(width: hexSize, height: hexSize)
        .scaleEffect(isConquered ? 1 : 0.9)
        .opacity(isShattered ? 1 : 0)
        .shadow(color: userColor.opacity(isConquered ? 0.62 : 0), radius: 28, y: 8)
    }

    /// Impact at the break. Deliberately a thin expanding rim over a weak wash rather
    /// than a solid white fill — a full flash blows out the shards at exactly the
    /// moment they separate, which is the frame worth seeing.
    private var impactFlash: some View {
        ZStack {
            ConquestHexagon()
                .fill(.white.opacity(0.3))

            ConquestHexagon()
                .stroke(.white, lineWidth: 7)
        }
        .frame(width: hexSize, height: hexSize)
        .scaleEffect(flashScale)
        .opacity(flashOpacity)
        .blendMode(.plusLighter)
    }

    private var energyRing: some View {
        ConquestHexagon()
            .stroke(userColor.opacity(0.68), lineWidth: 2.8)
            .frame(width: hexSize, height: hexSize)
            .scaleEffect(isConquered ? 1.58 : 0.92)
            .opacity(isConquered ? 0 : (isShattered ? 0.78 : 0))
            .animation(.easeOut(duration: 0.82), value: isConquered)
    }

    private var defenseTransferTrail: some View {
        GeometryReader { proxy in
            let startY = max(proxy.safeAreaInsets.top + 76, 112)
            let endY = proxy.size.height * 0.37
            let currentY = startY + (endY - startY) * defenseTransferProgress
            let trailHeight = max(currentY - startY, 0)
            let visibility = sin(Double(defenseTransferProgress) * .pi)

            ZStack {
                Capsule()
                    .fill(opponentColor.opacity(0.34))
                    .frame(width: 2, height: trailHeight)
                    .position(x: proxy.size.width / 2, y: startY + trailHeight / 2)

                Circle()
                    .fill(opponentColor)
                    .frame(width: 9, height: 9)
                    .shadow(color: opponentColor.opacity(0.9), radius: 8)
                    .position(x: proxy.size.width / 2, y: currentY)
            }
            .opacity(visibility)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }

    private var sparkBurst: some View {
        ForEach(0..<12, id: \.self) { index in
            let angle = (Double(index) * .pi / 6) - (.pi / 2)
            let distance = CGFloat(92 + (index % 3) * 18)
            let size = CGFloat(3 + (index % 3))
            let visibility = sin(Double(sparkProgress) * .pi)

            Circle()
                .fill(index.isMultiple(of: 2) ? Color.white : userColor)
                .frame(width: size, height: size)
                .offset(
                    x: CGFloat(cos(angle)) * distance * sparkProgress,
                    y: CGFloat(sin(angle)) * distance * sparkProgress
                )
                .opacity(visibility * 0.9)
                .shadow(color: userColor.opacity(0.55), radius: 4)
        }
    }

    /// One satellite hexagon per previously conquered cell in the current streak.
    /// They fly out from behind the main hexagon one by one, so a burst reads as a
    /// growing cluster instead of a single badge the player has to go looking for.
    private var comboHexagons: some View {
        ForEach(0..<min(max(comboCount - 1, 0), 6), id: \.self) { index in
            let angle = Angle.degrees(Double(index) * 60 - 30)
            ConquestHexagon()
                .fill(userColor.opacity(0.85))
                .overlay(ConquestHexagon().stroke(.white.opacity(0.85), lineWidth: 1.8))
                .frame(width: 64, height: 64)
                .shadow(color: userColor.opacity(0.7), radius: 14)
                .rotationEffect(.degrees(showSatellites ? 0 : -45))
                .offset(
                    x: cos(angle.radians) * (showSatellites ? 108 : 34),
                    y: sin(angle.radians) * (showSatellites ? 99 : 31)
                )
                .scaleEffect(showSatellites ? 1 : 0.12)
                .opacity(showSatellites ? 1 : 0)
                .animation(
                    .spring(response: 0.44, dampingFraction: 0.58)
                        .delay(Double(index) * 0.08),
                    value: showSatellites
                )
        }
    }

    private var conquestCopy: some View {
        VStack(spacing: 9) {
            Text("run.territoryConquered".localized)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if comboCount > 1 {
                HStack(spacing: 7) {
                    Image(systemName: "hexagon.fill")
                        .font(.caption.bold())
                    Text("run.conquest.streak".localized(with: comboCount))
                        .font(.subheadline.bold())
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(userColor.opacity(0.76), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.34), lineWidth: 1))
            }
        }
        .opacity(showDetails ? 1 : 0)
        .offset(y: showDetails ? 0 : 12)
    }

    private var accessibilityText: String {
        if comboCount > 1 {
            return "\("run.territoryConquered".localized) \("run.conquest.streak".localized(with: comboCount))"
        }
        return "run.territoryConquered".localized
    }

    // MARK: - Timeline

    @MainActor
    private func playAnimation() async {
        TerritoryConquestFeedback.shared.prepare()

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) {
                isVisible = true
                isCracked = true
                isShattered = true
                isConquered = true
                showSatellites = true
                showDetails = true
                crackProgress = 1
            }
            TerritoryConquestFeedback.shared.playBreak()
            try? await Task.sleep(for: .milliseconds(900))
        } else {
            // 1. Arrival — the opponent's tile lands.
            withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
                isVisible = true
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            // 2. The last defense energy travels from the HUD into the tile, linking
            //    the depleted bar to the break instead of starting a detached scene.
            withAnimation(.easeInOut(duration: 0.22)) {
                defenseTransferProgress = 1
            }
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }

            // 3. Tension and hit-stop — one readable impact replaces several small
            //    shakes, giving the break a cleaner and heavier silhouette.
            withAnimation(.easeIn(duration: 0.36)) {
                crackProgress = 1
                isCracked = true
                tileImpactScale = 0.96
            }
            try? await Task.sleep(for: .milliseconds(360))
            withAnimation(.linear(duration: 0.07)) {
                shakeOffset = -7
                tileImpactScale = 1.035
            }
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }

            // 4. Break — flash, shards fly, the conquered tile is uncovered.
            withAnimation(.easeOut(duration: 0.08)) {
                shakeOffset = 0
                tileImpactScale = 1
            }
            TerritoryConquestFeedback.shared.playBreak()
            withAnimation(.easeOut(duration: 0.07)) {
                flashOpacity = 0.95
                flashScale = 1.08
            }
            isShattered = true
            withAnimation(.easeOut(duration: 0.58)) {
                sparkProgress = 1
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.58).delay(0.05)) {
                isConquered = true
            }
            showSatellites = true

            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeOut(duration: 0.38)) {
                flashOpacity = 0
                flashScale = 1.75
            }
            try? await Task.sleep(for: .milliseconds(310))
            guard !Task.isCancelled else { return }

            // 5. Copy.
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                showDetails = true
            }
            try? await Task.sleep(for: .milliseconds(720))
        }

        guard !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: 0.2)) {
            isExiting = true
        }
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }
        onFinished()
    }
}

private struct ConquestHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for index in 0..<6 {
            let angle = (Double(index) * .pi / 3) - (.pi / 2)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// A single wedge of the hexagon: centre out to two adjacent corners. Six of these
/// tile the whole hexagon, which is what lets the tile break into its own geometry.
private struct ConquestShard: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        func corner(_ cornerIndex: Int) -> CGPoint {
            let angle = (Double(cornerIndex) * .pi / 3) - (.pi / 2)
            return CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
        }

        var path = Path()
        path.move(to: center)
        path.addLine(to: corner(index))
        path.addLine(to: corner(index + 1))
        path.closeSubpath()
        return path
    }
}

private struct ConquestCracks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Main fractures radiating from the impact point, each with a kink so they
        // read as splintered stone rather than clean spokes.
        let branches: [[CGPoint]] = [
            [center, point(0.44, 0.33, in: rect), point(0.30, 0.06, in: rect)],
            [center, point(0.66, 0.44, in: rect), point(0.95, 0.34, in: rect)],
            [center, point(0.59, 0.66, in: rect), point(0.73, 0.95, in: rect)],
            [center, point(0.38, 0.63, in: rect), point(0.12, 0.84, in: rect)],
            [center, point(0.31, 0.47, in: rect), point(0.03, 0.38, in: rect)],
            [center, point(0.52, 0.24, in: rect), point(0.62, 0.02, in: rect)]
        ]

        for branch in branches {
            guard let first = branch.first else { continue }
            path.move(to: first)
            for next in branch.dropFirst() {
                path.addLine(to: next)
            }
        }

        // Short splinters hanging off the main fractures.
        let splinters: [(CGPoint, CGPoint)] = [
            (point(0.44, 0.33, in: rect), point(0.58, 0.14, in: rect)),
            (point(0.66, 0.44, in: rect), point(0.82, 0.60, in: rect)),
            (point(0.59, 0.66, in: rect), point(0.36, 0.84, in: rect)),
            (point(0.38, 0.63, in: rect), point(0.18, 0.56, in: rect)),
            (point(0.31, 0.47, in: rect), point(0.20, 0.28, in: rect))
        ]

        for (start, end) in splinters {
            path.move(to: start)
            path.addLine(to: end)
        }

        return path
    }

    private func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
    }
}
