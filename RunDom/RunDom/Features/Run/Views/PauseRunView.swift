import SwiftUI

struct PauseRunView: View {
    let elapsedTime: String
    let distance: Double // km
    let onResume: () -> Void
    let onStop: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Pause icon
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)

                Text("run.paused".localized)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                // Current stats
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text(distance.formattedDistance)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 4) {
                        Text(elapsedTime)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("run.time".localized)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    Button {
                        onResume()
                    } label: {
                        Label("run.resume".localized, systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius))
                    }

                    SlideToFinishControl(onComplete: onStop)
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.bottom, 40)
            }
        }
    }
}

struct SlideToFinishControl: View {
    @Environment(\.colorScheme) private var colorScheme

    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isCompleting = false

    private let knobSize: CGFloat = 54
    private let horizontalInset: CGFloat = 6
    private let finishColor = Color(red: 1.0, green: 0.27, blue: 0.30)

    var body: some View {
        GeometryReader { proxy in
            let maxOffset = max(proxy.size.width - knobSize - (horizontalInset * 2), 0)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(finishColor)

                HStack {
                    Spacer()
                    Text("run.slideToFinish".localized)
                        .font(.headline.bold())
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer()
                }
                .padding(.horizontal, 56)

                HStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "chevron.right")
                    Image(systemName: "chevron.right")
                }
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.35))
                .padding(.trailing, 20)

                Circle()
                    .fill(Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .overlay {
                        Circle()
                            .stroke(
                                finishColor.opacity(colorScheme == .dark ? 0.30 : 0.14),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        Image(systemName: "stop.fill")
                            .font(.headline.bold())
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(finishColor)
                    }
                    .shadow(
                        color: finishColor.opacity(colorScheme == .dark ? 0.22 : 0.10),
                        radius: 5,
                        y: 2
                    )
                    .offset(x: horizontalInset + dragOffset)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard !isCompleting else { return }
                                dragOffset = min(max(value.translation.width, 0), maxOffset)
                            }
                            .onEnded { _ in
                                guard !isCompleting else { return }

                                if dragOffset > maxOffset * 0.82 {
                                    isCompleting = true
                                    dragOffset = maxOffset
                                    Haptics.notification(.success)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                        onComplete()
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: 64)
    }
}
