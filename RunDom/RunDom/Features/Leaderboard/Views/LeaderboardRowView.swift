import SwiftUI

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool
    /// Points needed to overtake the rank directly above. Only surfaced for the current user.
    var pointsToPass: Double?

    private var userColor: Color {
        Color(hex: entry.color) ?? .accentColor
    }

    private var accent: Color {
        isCurrentUser ? .accentColor : userColor
    }

    var body: some View {
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

                if isCurrentUser, let gap = pointsToPass, gap > 0 {
                    gapChip(gap)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, AppConstants.UI.cardPadding)
        .background(rowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isCurrentUser ? Color.accentColor.opacity(0.55) : userColor.opacity(0.18),
                    lineWidth: isCurrentUser ? 1.5 : 1
                )
        )
        .overlay(alignment: .leading) {
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
        .shadow(color: isCurrentUser ? Color.accentColor.opacity(0.18) : .clear, radius: 10, x: 0, y: 4)
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

    private func gapChip(_ gap: Double) -> some View {
        let value = "\(gap.formattedTrail) \("trail.unit".localized)"
        return HStack(spacing: 3) {
            Image(systemName: "arrow.up")
                .font(.system(size: 8, weight: .bold))
            Text("leaderboard.gap.toPass".localized(with: value))
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color.accentColor)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Color.accentColor.opacity(0.14), in: Capsule())
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(uiColor: .secondarySystemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(isCurrentUser ? 0.22 : 0.12),
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
