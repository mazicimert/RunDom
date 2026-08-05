import SwiftUI
import Lottie

struct SplashView: View {
    let onFinish: () -> Void

    private let animationName = "Running_character"
    private let fallbackDuration: TimeInterval = 2.2
    private let movementDurationRatio: TimeInterval = 0.90
    private let characterSizeRatio: CGFloat = 0.37
    private let title = "RunPire"

    private let territoryBlue = Color(red: 0.184, green: 0.502, blue: 1.000)

    @State private var movementProgress: CGFloat = 0
    @State private var triggeredHexes: Set<Int> = []
    @State private var titleVisible = false
    @State private var decorativeDrift = false
    @State private var routePulse = false
    @State private var hasStarted = false
    @State private var didFinish = false

    var body: some View {
        GeometryReader { proxy in
            let route = routeCells(in: proxy.size)
            let decoration = decorativeCells(in: proxy.size)
            let characterSize = min(proxy.size.width * characterSizeRatio, 184)
            let start = CGPoint(
                x: -(characterSize / 2) - 24,
                y: proxy.size.height * 0.55
            )
            let end = CGPoint(
                x: proxy.size.width + (characterSize / 2) + 24,
                y: proxy.size.height * 0.55
            )
            let runnerPosition = CGPoint(
                x: start.x + (end.x - start.x) * movementProgress,
                y: start.y + (end.y - start.y) * movementProgress
            )

            ZStack {
                background(in: proxy.size)

                decorativeHexLayer(cells: decoration)
                routeHexLayer(cells: route)

                titleView
                    .position(
                        x: proxy.size.width / 2,
                        y: max(82, proxy.size.height * 0.23)
                    )

                Ellipse()
                    .fill(.black.opacity(0.28))
                    .frame(width: characterSize * 0.42, height: characterSize * 0.075)
                    .blur(radius: 7)
                    .position(
                        x: runnerPosition.x,
                        y: runnerPosition.y + characterSize * 0.31
                    )

                LottieView(
                    animationName: animationName,
                    loopMode: .playOnce,
                    contentMode: .scaleAspectFit,
                    animationSpeed: 1
                )
                .frame(width: characterSize, height: characterSize)
                .position(runnerPosition)
                .shadow(color: territoryBlue.opacity(0.42), radius: 16)
            }
            .onAppear {
                startIfNeeded(route: route, start: start, end: end)
            }
        }
    }

    // MARK: - Layers

    private func background(in size: CGSize) -> some View {
        LinearGradient(
            colors: [
                Color(red: 0.035, green: 0.051, blue: 0.094),
                Color(red: 0.055, green: 0.078, blue: 0.137),
                Color(red: 0.039, green: 0.059, blue: 0.110)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RadialGradient(
                colors: [
                    territoryBlue.opacity(0.26),
                    territoryBlue.opacity(0.08),
                    .clear
                ],
                center: .center,
                startRadius: 24,
                endRadius: size.width * 0.88
            )
        }
        .ignoresSafeArea()
    }

    private func decorativeHexLayer(cells: [SplashHexCell]) -> some View {
        ZStack {
            ForEach(cells) { cell in
                let direction: CGFloat = cell.id.isMultiple(of: 2) ? 1 : -1
                HexagonShape()
                    .fill(cell.color.opacity(cell.opacity))
                    .overlay {
                        HexagonShape()
                            .stroke(.white.opacity(0.055), lineWidth: 1)
                    }
                    .frame(width: cell.size.width, height: cell.size.height)
                    .rotationEffect(.degrees(cell.rotation + (decorativeDrift ? 1.5 : -1.5) * Double(direction)))
                    .position(cell.center)
                    .offset(
                        x: direction * (decorativeDrift ? 3 : -3),
                        y: direction * (decorativeDrift ? -2 : 2)
                    )
                    .animation(
                        .easeInOut(duration: 2.35 + Double(cell.id % 3) * 0.18)
                            .repeatForever(autoreverses: true),
                        value: decorativeDrift
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func routeHexLayer(cells: [SplashHexCell]) -> some View {
        ZStack {
            ForEach(cells) { cell in
                ConquerableSplashHex(
                    cell: cell,
                    territoryBlue: territoryBlue,
                    isTriggered: triggeredHexes.contains(cell.id),
                    routePulse: routePulse
                )
            }
        }
        .allowsHitTesting(false)
    }

    private var titleView: some View {
        HStack(spacing: 1) {
            ForEach(Array(title.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.97))
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 10)
                    .blur(radius: titleVisible ? 0 : 3)
                    .animation(
                        .spring(response: 0.38, dampingFraction: 0.78)
                            .delay(Double(index) * 0.045),
                        value: titleVisible
                    )
            }
        }
        .shadow(color: territoryBlue.opacity(0.42), radius: 18)
    }

    // MARK: - Layout

    private func routeCells(in size: CGSize) -> [SplashHexCell] {
        let width = size.width * 0.18
        let height = width * 2 / sqrt(3)
        let positions: [(CGFloat, CGFloat)] = [
            (-0.08, 0.55),
            (0.10, 0.55),
            (0.28, 0.55),
            (0.46, 0.55),
            (0.64, 0.55),
            (0.82, 0.55),
            (1.00, 0.55)
        ]
        let colors: [Color] = [
            Color(red: 0.96, green: 0.52, blue: 0.58),
            Color(red: 0.98, green: 0.72, blue: 0.40),
            Color(red: 0.43, green: 0.83, blue: 0.72),
            Color(red: 0.69, green: 0.58, blue: 0.94),
            Color(red: 0.95, green: 0.57, blue: 0.77),
            Color(red: 0.96, green: 0.64, blue: 0.38),
            Color(red: 0.48, green: 0.78, blue: 0.92)
        ]

        return positions.enumerated().map { index, position in
            SplashHexCell(
                id: index,
                center: CGPoint(x: size.width * position.0, y: size.height * position.1),
                size: CGSize(width: width, height: height),
                color: colors[index],
                opacity: 0.74,
                rotation: 0
            )
        }
    }

    private func decorativeCells(in size: CGSize) -> [SplashHexCell] {
        let specs: [(CGFloat, CGFloat, CGFloat, Color, Double, Double)] = [
            (0.12, 0.20, 0.13, Color(red: 0.43, green: 0.83, blue: 0.72), 0.14, -7),
            (0.49, 0.11, 0.08, Color(red: 0.98, green: 0.72, blue: 0.40), 0.11, 9),
            (0.86, 0.20, 0.12, Color(red: 0.96, green: 0.52, blue: 0.58), 0.15, 6),
            (0.12, 0.84, 0.11, Color(red: 0.98, green: 0.72, blue: 0.40), 0.11, 8),
            (0.50, 0.90, 0.08, Color(red: 0.95, green: 0.57, blue: 0.77), 0.09, -5),
            (0.83, 0.82, 0.13, Color(red: 0.43, green: 0.83, blue: 0.72), 0.12, 7)
        ]

        return specs.enumerated().map { index, spec in
            let width = size.width * spec.2
            return SplashHexCell(
                id: 100 + index,
                center: CGPoint(x: size.width * spec.0, y: size.height * spec.1),
                size: CGSize(width: width, height: width * 2 / sqrt(3)),
                color: spec.3,
                opacity: spec.4,
                rotation: spec.5
            )
        }
    }

    // MARK: - Choreography

    private func startIfNeeded(route: [SplashHexCell], start: CGPoint, end: CGPoint) {
        guard !hasStarted else { return }
        hasStarted = true

        DispatchQueue.main.async {
            titleVisible = true
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                decorativeDrift = true
            }
        }

        let movementDuration = max(
            0.65,
            (LottieAnimation.named(animationName)?.duration ?? fallbackDuration) * movementDurationRatio
        )

        withAnimation(.linear(duration: movementDuration)) {
            movementProgress = 1
        }

        let travel = max(end.x - start.x, 1)
        for cell in route {
            let reach = min(max((cell.center.x - start.x) / travel - 0.065, 0), 1)
            let delay = Double(reach) * movementDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                _ = triggeredHexes.insert(cell.id)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + movementDuration * 0.84) {
            withAnimation(.easeOut(duration: 0.10)) {
                routePulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.20)) {
                    routePulse = false
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + movementDuration) {
            finishIfNeeded()
        }
    }

    private func finishIfNeeded() {
        guard !didFinish else { return }
        didFinish = true
        onFinish()
    }
}

// MARK: - Conquest animation

private struct ConquerableSplashHex: View {
    let cell: SplashHexCell
    let territoryBlue: Color
    let isTriggered: Bool
    let routePulse: Bool

    @State private var intactVisible = true
    @State private var intactScaleX: CGFloat = 1
    @State private var intactScaleY: CGFloat = 1
    @State private var shardsVisible = false
    @State private var cracksVisible = false
    @State private var shardsExpanded = false
    @State private var shardsFaded = false
    @State private var blueVisible = false
    @State private var blueScale: CGFloat = 0.64
    @State private var ringScale: CGFloat = 0.78
    @State private var ringOpacity: Double = 0
    @State private var blueWaveVisible = false
    @State private var blueWaveScale: CGFloat = 0.22
    @State private var blueWaveOpacity: Double = 0

    var body: some View {
        ZStack {
            if blueVisible {
                HexagonShape()
                    .stroke(territoryBlue.opacity(0.48), lineWidth: 12)
                    .blur(radius: 10)
                    .scaleEffect(blueScale * (routePulse ? 1.10 : 1.06))

                HexagonShape()
                    .fill(territoryBlue)
                    .overlay {
                        HexagonShape()
                            .stroke(.white.opacity(0.72), lineWidth: 2.2)
                    }
                    .scaleEffect(blueScale * (routePulse ? 1.045 : 1))
                    .shadow(
                        color: territoryBlue.opacity(routePulse ? 0.82 : 0),
                        radius: routePulse ? 12 : 0
                    )

                if blueWaveVisible {
                    HexagonShape()
                        .stroke(.white.opacity(blueWaveOpacity), lineWidth: 3.4)
                        .scaleEffect(blueWaveScale)
                }
            }

            if intactVisible {
                HexagonShape()
                    .fill(cell.color.opacity(cell.opacity))
                    .overlay {
                        HexagonShape()
                            .stroke(cell.color.opacity(0.92), lineWidth: 1.6)
                    }
                    .scaleEffect(x: intactScaleX, y: intactScaleY)
            }

            if shardsVisible {
                ForEach(0..<6, id: \.self) { index in
                    let angle = Double(index) * 60 - 60
                    HexWedgeShape(index: index)
                        .fill(cell.color.opacity(shardsFaded ? 0 : 0.96))
                        .overlay {
                            HexWedgeShape(index: index)
                                .stroke(.white.opacity(shardsFaded ? 0 : 0.58), lineWidth: 1.8)
                        }
                        .offset(
                            x: shardsExpanded
                                ? (CGFloat(cos(angle * .pi / 180)) * cell.size.width * 0.44 + cell.size.width * 0.18)
                                : 0,
                            y: shardsExpanded ? CGFloat(sin(angle * .pi / 180)) * cell.size.width * 0.48 : 0
                        )
                        .rotationEffect(.degrees(shardsExpanded ? (index.isMultiple(of: 2) ? 12 : -12) : 0))
                        .scaleEffect(shardsExpanded ? 0.78 : 1)
                }
            }

            if cracksVisible {
                CrackShape()
                    .stroke(.white.opacity(0.94), style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                    .padding(cell.size.width * 0.10)
            }

            HexagonShape()
                .stroke(.white.opacity(ringOpacity), lineWidth: 3.2)
                .scaleEffect(ringScale)
        }
        .frame(width: cell.size.width, height: cell.size.height)
        .position(cell.center)
        .animation(.easeInOut(duration: 0.16), value: routePulse)
        .onChange(of: isTriggered) { _, triggered in
            guard triggered, intactVisible else { return }
            playImpact()
        }
    }

    private func playImpact() {
        cracksVisible = true
        ringOpacity = 0.9
        withAnimation(.easeOut(duration: 0.06)) {
            intactScaleX = 0.78
            intactScaleY = 1.07
            ringScale = 1.06
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            intactVisible = false
            shardsVisible = true
            withAnimation(.easeOut(duration: 0.28)) {
                shardsExpanded = true
                ringScale = 1.72
                ringOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            blueVisible = true
            blueWaveVisible = true
            blueWaveOpacity = 0.82
            withAnimation(.spring(response: 0.34, dampingFraction: 0.58)) {
                blueScale = 1
            }
            withAnimation(.easeOut(duration: 0.24)) {
                blueWaveScale = 1.24
                blueWaveOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.31) {
            cracksVisible = false
            withAnimation(.easeOut(duration: 0.16)) {
                shardsFaded = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            shardsVisible = false
            blueWaveVisible = false
        }
    }
}

private struct SplashHexCell: Identifiable {
    let id: Int
    let center: CGPoint
    let size: CGSize
    let color: Color
    let opacity: Double
    let rotation: Double
}

private struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.75))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.75))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25))
        path.closeSubpath()
        return path
    }
}

private struct CrackShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        let endpoints: [(CGFloat, CGFloat)] = [
            (0.50, 0.00), (0.96, 0.30), (0.88, 0.78),
            (0.50, 1.00), (0.08, 0.72), (0.02, 0.28)
        ]
        for (index, endpoint) in endpoints.enumerated() {
            let bend = CGPoint(
                x: rect.width * (index.isMultiple(of: 2) ? 0.56 : 0.43),
                y: rect.height * (index < 3 ? 0.42 : 0.60)
            )
            path.move(to: center)
            path.addLine(to: bend)
            path.addLine(to: CGPoint(x: rect.width * endpoint.0, y: rect.height * endpoint.1))
        }
        return path
    }
}

private struct HexWedgeShape: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        let vertices = [
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25),
            CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.75),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.75),
            CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25)
        ]
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: vertices[index])
        path.addLine(to: vertices[(index + 1) % vertices.count])
        path.closeSubpath()
        return path
    }
}

#Preview {
    SplashView(onFinish: {})
}
