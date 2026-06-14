import SwiftUI

struct DailyChallengeSelectionView: View {
    @Environment(\.colorScheme) private var colorScheme

    let state: DailyChallengeState
    let isSelecting: Bool
    let onClose: () -> Void
    let onSelect: (DailyChallengeTemplate) -> Void

    private let cardCornerRadius: CGFloat = 24

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header

                VStack(spacing: 14) {
                    selectionCard(challenge: state.safeChallenge)
                        .appearTransition(delay: 0.06)

                    selectionCard(challenge: state.difficultChallenge)
                        .appearTransition(delay: 0.14)
                }

                Text("challenge.selection.footnote".localized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(challengeBackground)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(ChallengeTheme.cardFill, in: Circle())
                        .overlay(Circle().stroke(ChallengeTheme.cardBorder(colorScheme), lineWidth: 1))
                }
                .accessibilityLabel("challenge.selection.skip".localized)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("challenge.selection.title".localized)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("challenge.selection.subtitle".localized)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
        .appearTransition()
    }

    // MARK: - Selection Card

    @ViewBuilder
    private func selectionCard(challenge: DailyChallengeTemplate) -> some View {
        let accentColor = challengeAccentColor(for: challenge)

        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: challenge.difficulty == .safe ? "shield.fill" : "sparkles")
                    .font(.headline.bold())
                    .foregroundStyle(accentColor)
                    .frame(width: 46, height: 46)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(challenge.difficulty.localizedLabel)
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(accentColor)

                    Text(challenge.localizedTitle)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            VStack(alignment: .leading, spacing: 8) {
                detailRow(icon: "target", text: challenge.targetText)
                detailRow(icon: "star.fill", text: challenge.rewardText)
            }

            Button {
                onSelect(challenge)
            } label: {
                Group {
                    if isSelecting {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("challenge.selection.action".localized)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(ChallengeSelectionButtonStyle(color: accentColor))
            .disabled(isSelecting)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(ChallengeTheme.cardFill, in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(ChallengeTheme.cardBorder(colorScheme), lineWidth: 1)
        )
        .shadow(color: ChallengeTheme.cardShadow(colorScheme), radius: 18, x: 0, y: 10)
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Background

    private var challengeBackground: some View {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
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

// MARK: - Button Style

private struct ChallengeSelectionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .background(
                Capsule()
                    .fill(color)
                    .shadow(color: color.opacity(configuration.isPressed ? 0.0 : 0.30), radius: 14, x: 0, y: 7)
            )
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: AppConstants.Animation.quick), value: configuration.isPressed)
    }
}

// MARK: - Theme (mirrors PreRunView's light, system-color card language)

private enum ChallengeTheme {
    static var cardFill: Color { Color.cardBackground }

    static func cardBorder(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.04)
    }

    static func cardShadow(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.22)
            : Color.black.opacity(0.04)
    }
}

// MARK: - Motion

private struct AppearTransition: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45).delay(delay)) {
                    shown = true
                }
            }
    }
}

private extension View {
    func appearTransition(delay: Double = 0) -> some View {
        modifier(AppearTransition(delay: delay))
    }
}
