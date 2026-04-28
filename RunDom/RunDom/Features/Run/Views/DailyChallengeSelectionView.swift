import SwiftUI

struct DailyChallengeSelectionView: View {
    let state: DailyChallengeState
    let isSelecting: Bool
    let onClose: () -> Void
    let onSelect: (DailyChallengeTemplate) -> Void

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = AppConstants.UI.screenPadding
            let cardWidth = proxy.size.width - (horizontalPadding * 2)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Spacer()

                        Button("challenge.selection.skip".localized) {
                            onClose()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("challenge.selection.title".localized)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)

                        Text("challenge.selection.subtitle".localized)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    VStack(spacing: 14) {
                        selectionCard(
                            challenge: state.safeChallenge,
                            width: cardWidth
                        )

                        selectionCard(
                            challenge: state.difficultChallenge,
                            width: cardWidth
                        )
                    }

                    Text("challenge.selection.footnote".localized)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(.systemGray6).opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private func selectionCard(challenge: DailyChallengeTemplate, width: CGFloat) -> some View {
        let accentColor = challengeAccentColor(for: challenge)

        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(challenge.difficulty.localizedLabel)
                    .font(.caption.bold())
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accentColor.opacity(0.14), in: Capsule())

                Spacer(minLength: 8)

                Text(challenge.rewardText)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(challenge.localizedTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(challenge.targetText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer(minLength: 0)

            Button {
                onSelect(challenge)
            } label: {
                if isSelecting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("challenge.selection.action".localized)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(ChallengeSelectionButtonStyle(color: accentColor))
            .disabled(isSelecting)
        }
        .padding(18)
        .frame(width: width, alignment: .topLeading)
        .frame(minHeight: 240, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.26),
                            Color(red: 0.13, green: 0.13, blue: 0.17),
                            Color(red: 0.10, green: 0.10, blue: 0.13)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(accentColor.opacity(0.5), lineWidth: 1.5)
        )
    }

    private func challengeAccentColor(for challenge: DailyChallengeTemplate) -> Color {
        switch challenge.difficulty {
        case .safe:
            return .boostGreen
        case .difficult:
            return .orange
        }
    }
}

private struct ChallengeSelectionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.78 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: AppConstants.Animation.quick), value: configuration.isPressed)
    }
}
