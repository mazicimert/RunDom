import SwiftUI

/// Coordinate space the leaderboard scroll view publishes so rows can report
/// whether the current user's row is on-screen.
let leaderboardScrollSpace = "leaderboardScroll"

/// Frame of the current user's row, in `leaderboardScrollSpace` coordinates.
/// Used to decide whether the pinned "Your position" card should appear.
struct LeaderboardCurrentUserFrameKey: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool
    /// Points needed to overtake the rank directly above. Only surfaced for the current user.
    var pointsToPass: Double?
    /// When embedded inside the pinned card, the row drops its own background,
    /// border, rail and shadow so the card provides the single source of chrome.
    var isEmbedded: Bool = false

    private var userColor: Color {
        Color(hex: entry.color) ?? .accentColor
    }

    private var accent: Color {
        isCurrentUser ? .accentColor : userColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                rankMedallion

                AvatarView(
                    photoURL: entry.photoURL,
                    userColor: entry.color,
                    size: 44
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.displayName)
                            .font(.subheadline.bold())
                            .lineLimit(1)

                        if isCurrentUser {
                            youTag
                        }
                    }

                    HStack(spacing: 8) {
                        if let neighborhood = entry.neighborhood, !neighborhood.isEmpty {
                            Text(neighborhood)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if entry.territoriesOwned > 0 {
                            territoryBadge
                        }
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.trail.formattedTrail)
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(isCurrentUser ? Color.accentColor : .primary)

                    Text("trail.unit".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Full-width gap banner: lives on its own line so the
            // "X Points to pass…" copy is never squeezed/truncated.
            if isCurrentUser, let gap = pointsToPass, gap > 0 {
                gapBanner(gap)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, isEmbedded ? 0 : AppConstants.UI.cardPadding)
        .background {
            if !isEmbedded { rowBackground }
        }
        .overlay {
            if !isEmbedded {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isCurrentUser ? Color.accentColor.opacity(0.35) : userColor.opacity(0.16),
                        lineWidth: 1
                    )
            }
        }
        .overlay(alignment: .leading) {
            if !isEmbedded {
                // Territory-tinted rank rail
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
                    .padding(.vertical, 14)
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Pieces

    private var rankMedallion: some View {
        Text("\(entry.rank)")
            .font(.footnote.bold().monospacedDigit())
            .foregroundStyle(isCurrentUser ? Color.white : accent)
            .frame(width: 30, height: 30)
            .background {
                Circle()
                    .fill(
                        isCurrentUser
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing))
                            : AnyShapeStyle(accent.opacity(0.16))
                    )
            }
            .overlay(
                Circle().stroke(accent.opacity(isCurrentUser ? 0 : 0.4), lineWidth: 1)
            )
    }

    private var youTag: some View {
        Text("leaderboard.you".localized)
            .font(.caption2.bold())
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.16), in: Capsule())
    }

    private var territoryBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "hexagon.fill")
                .font(.system(size: 8))
            Text("leaderboard.territories".localized(with: entry.territoriesOwned))
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(userColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(userColor.opacity(0.14), in: Capsule())
    }

    private func gapBanner(_ gap: Double) -> some View {
        let value = "\(gap.formattedTrail) \("trail.unit".localized)"
        return HStack(spacing: 6) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.caption)
            Text("leaderboard.gap.toPass".localized(with: value))
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.accentColor.opacity(0.14),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(uiColor: .secondarySystemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(isCurrentUser ? 0.14 : 0.10),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .center
                        )
                    )
            }
    }
}

#Preview {
    VStack(spacing: 12) {
        LeaderboardRowView(
            entry: LeaderboardEntry(
                id: "1", userId: "u1", displayName: "Runner One",
                photoURL: nil, color: "#FF6B6B", trail: 12500,
                rank: 4, neighborhood: "Kadıköy", seasonId: "s1", territoriesOwned: 15
            ),
            isCurrentUser: false
        )
        LeaderboardRowView(
            entry: LeaderboardEntry(
                id: "2", userId: "u2", displayName: "You",
                photoURL: nil, color: "#4ECDC4", trail: 8300,
                rank: 5, neighborhood: "Beşiktaş", seasonId: "s1", territoriesOwned: 8
            ),
            isCurrentUser: true,
            pointsToPass: 4200
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}
