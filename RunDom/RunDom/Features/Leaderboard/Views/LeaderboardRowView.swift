import SwiftUI

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(entry.rank)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(isCurrentUser ? Color.accentColor : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    (isCurrentUser ? Color.accentColor.opacity(0.16) : Color(uiColor: .tertiarySystemBackground)),
                    in: Capsule()
                )

            // Avatar
            AvatarView(
                photoURL: entry.photoURL,
                userColor: entry.color,
                size: 40
            )

            // Name & Neighborhood
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                if let neighborhood = entry.neighborhood {
                    Text(neighborhood)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Trail Points
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.trail.formattedTrail)
                    .font(.subheadline.bold().monospacedDigit())

                Text("trail.unit".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, AppConstants.UI.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isCurrentUser ? Color.accentColor.opacity(0.1) : Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isCurrentUser ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    VStack {
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
            isCurrentUser: true
        )
    }
    .padding()
}
