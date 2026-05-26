import SwiftUI
import Lottie

struct SplashView: View {
    let onFinish: () -> Void

    private let animationName = "Running_character"
    private let fallbackDuration: TimeInterval = 2.2
    private let characterSizeRatio: CGFloat = 0.36
    private let offscreenTravelPadding: CGFloat = 24
    private let movementDurationRatio: CGFloat = 0.90
    private let title = "Runpire"

    // Brand paint color for the conquered hexagon trail (dark-mode TerritoryBlue).
    private let paintColor = Color(red: 0.333, green: 0.533, blue: 0.967)

    @State private var movementProgress: CGFloat = 0
    @State private var revealedHexes: Set<Int> = []
    @State private var titleVisible = false
    @State private var movementDidComplete = false
    @State private var hasStarted = false
    @State private var didFinish = false

    var body: some View {
        GeometryReader { proxy in
            let cells = hexCells(in: proxy.size)
            let characterSize = min(proxy.size.width * characterSizeRatio, 180)
            let yPosition = proxy.size.height * 0.55
            let startX = -(characterSize / 2) - offscreenTravelPadding
            let endX = proxy.size.width + (characterSize / 2) + offscreenTravelPadding

            ZStack {
                background(in: proxy.size)

                hexLayer(cells: cells)

                titleView
                    .position(
                        x: proxy.size.width / 2,
                        y: max(64, proxy.size.height * 0.22)
                    )

                LottieView(
                    animationName: animationName,
                    loopMode: .playOnce,
                    contentMode: .scaleAspectFit
                )
                .frame(width: characterSize, height: characterSize)
                .position(
                    x: startX + (endX - startX) * movementProgress,
                    y: yPosition
                )
            }
            .onAppear {
                startIfNeeded(cells: cells, startX: startX, endX: endX)
            }
        }
    }

    // MARK: - Layers

    private func background(in size: CGSize) -> some View {
        LinearGradient(
            colors: [
                Color(red: 0.01, green: 0.08, blue: 0.22),
                Color(red: 0.03, green: 0.18, blue: 0.43),
                Color(red: 0.06, green: 0.30, blue: 0.62)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay {
            RadialGradient(
                colors: [
                    Color(red: 0.28, green: 0.66, blue: 1.00).opacity(0.30),
                    Color(red: 0.14, green: 0.46, blue: 0.86).opacity(0.14),
                    .clear
                ],
                center: .bottom,
                startRadius: 36,
                endRadius: size.height * 0.62
            )
        }
        .ignoresSafeArea()
    }

    private func hexLayer(cells: [HexCell]) -> some View {
        ZStack {
            ForEach(cells) { cell in
                let active = revealedHexes.contains(cell.id)
                HexagonShape()
                    .fill(paintColor.opacity(active ? cell.fillOpacity : 0))
                    .overlay {
                        HexagonShape()
                            .stroke(
                                paintColor.opacity(active ? 0.95 : 0.10),
                                lineWidth: active ? 1.6 : 1.0
                            )
                    }
                    .frame(width: cell.size.width, height: cell.size.height)
                    .scaleEffect(active ? 1 : 0.55)
                    .shadow(
                        color: paintColor.opacity(active ? 0.55 : 0),
                        radius: active ? 10 : 0
                    )
                    .position(cell.center)
            }
        }
        .allowsHitTesting(false)
    }

    private var titleView: some View {
        HStack(spacing: 1) {
            ForEach(Array(title.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 16)
                    .blur(radius: titleVisible ? 0 : 6)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.72)
                            .delay(0.15 + Double(index) * 0.06),
                        value: titleVisible
                    )
            }
        }
        .shadow(color: paintColor.opacity(0.45), radius: 18)
    }

    // MARK: - Hex layout

    private func hexCells(in size: CGSize) -> [HexCell] {
        guard size.width > 0, size.height > 0 else { return [] }

        let hexWidth = size.width / 5.5
        let hexHeight = hexWidth * 2 / sqrt(3) // pointy-top aspect
        let halfStep = hexHeight / 2           // vertical span of half a hex
        let rowSpacing = halfStep * 1.5
        let bandCenterY = size.height * 0.55

        var cells: [HexCell] = []
        let rows = [-1, 0, 1]
        let columnCount = Int(size.width / hexWidth) + 3

        for row in rows {
            let isOdd = row % 2 != 0
            let xOffset = isOdd ? hexWidth / 2 : 0
            let depth = abs(row)
            // Center row most opaque; outer rows fade for depth.
            let fillOpacity = 0.42 - CGFloat(depth) * 0.12
            let centerY = bandCenterY + CGFloat(row) * rowSpacing

            for col in -1...columnCount {
                let centerX = CGFloat(col) * hexWidth + xOffset
                cells.append(
                    HexCell(
                        id: cells.count,
                        center: CGPoint(x: centerX, y: centerY),
                        size: CGSize(width: hexWidth * 0.92, height: hexHeight * 0.92),
                        fillOpacity: max(0.16, fillOpacity)
                    )
                )
            }
        }
        return cells
    }

    // MARK: - Choreography

    private func startIfNeeded(cells: [HexCell], startX: CGFloat, endX: CGFloat) {
        guard !hasStarted else { return }
        hasStarted = true

        let duration = resolveDuration()
        let movementDuration = max(0.65, duration * movementDurationRatio)

        titleVisible = true

        withAnimation(.linear(duration: movementDuration)) {
            movementProgress = 1
        }

        // Light up each hexagon as the runner sweeps past its center.
        let travel = max(endX - startX, 1)
        for cell in cells {
            let reach = (cell.center.x - startX) / travel
            let delay = Double(min(max(reach, 0), 1)) * movementDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                    _ = revealedHexes.insert(cell.id)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + movementDuration) {
            movementDidComplete = true
            completeIfNeeded()
        }
    }

    private func resolveDuration() -> TimeInterval {
        let lottieDuration = LottieAnimation.named(animationName)?.duration
        return max(0.8, lottieDuration ?? fallbackDuration)
    }

    private func completeIfNeeded() {
        guard movementDidComplete, !didFinish else { return }
        didFinish = true
        onFinish()
    }
}

// MARK: - Supporting types

private struct HexCell: Identifiable {
    let id: Int
    let center: CGPoint
    let size: CGSize
    let fillOpacity: CGFloat
}

private struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.25))
        path.addLine(to: CGPoint(x: w, y: h * 0.75))
        path.addLine(to: CGPoint(x: w * 0.5, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.75))
        path.addLine(to: CGPoint(x: 0, y: h * 0.25))
        path.closeSubpath()
        return path
    }
}

#Preview {
    SplashView(onFinish: {})
}