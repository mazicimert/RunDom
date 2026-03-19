import SwiftUI

struct LeaderboardListView: View {
    let entries: [LeaderboardEntry]
    let currentUserId: String?

    var body: some View {
        let podium = Array(entries.prefix(3))
        let rest = Array(entries.dropFirst(3))

        VStack(spacing: 0) {
            // Podium (top 3)
            if !podium.isEmpty {
                PodiumView(entries: podium, currentUserId: currentUserId)
                    .padding(.bottom, 22)
            }

            // Remaining entries
            if !rest.isEmpty {
                LazyVStack(spacing: 10) {
                    ForEach(rest) { entry in
                        LeaderboardRowView(
                            entry: entry,
                            isCurrentUser: entry.userId == currentUserId
                        )
                    }
                }
                .screenPadding()
            }
        }
    }
}

// MARK: - Podium View

private struct PodiumView: View {
    let entries: [LeaderboardEntry]
    let currentUserId: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // 2nd place
            if entries.count > 1 {
                podiumItem(entry: entries[1], height: 80)
            }

            // 1st place
            if !entries.isEmpty {
                podiumItem(entry: entries[0], height: 100)
            }

            // 3rd place
            if entries.count > 2 {
                podiumItem(entry: entries[2], height: 65)
            }
        }
        .padding(.top, 16)
        .screenPadding()
    }

    private func podiumItem(entry: LeaderboardEntry, height: CGFloat) -> some View {
        VStack(spacing: 8) {
            // Crown for #1
            if entry.rank == 1 {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
            }

            // Avatar
            AvatarView(
                photoURL: entry.photoURL,
                userColor: entry.color,
                size: entry.rank == 1 ? 64 : 52
            )

            // Name
            Text(entry.displayName)
                .font(.caption.bold())
                .lineLimit(1)

            // Trail
            Text(entry.trail.formattedTrail)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

            // Rank badge
            Text("#\(entry.rank)")
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(rankColor(for: entry.rank).opacity(0.15))
                .foregroundStyle(rankColor(for: entry.rank))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .frame(height: height + 74)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                .fill(
                    entry.rank == 1
                        ? LinearGradient(
                            colors: [Color.yellow.opacity(0.2), Color.accentColor.opacity(0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        : LinearGradient(
                            colors: [
                                entry.userId == currentUserId ? Color.accentColor.opacity(0.14) : Color.clear,
                                Color(uiColor: .secondarySystemBackground)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }
}

#Preview {
    LeaderboardListView(
        entries: [
            LeaderboardEntry(id: "1", userId: "u1", displayName: "Champion", photoURL: nil, color: "#FF6B6B", trail: 25000, rank: 1, neighborhood: "Kadıköy", seasonId: "s1", territoriesOwned: 30),
            LeaderboardEntry(id: "2", userId: "u2", displayName: "Runner Up", photoURL: nil, color: "#4ECDC4", trail: 18500, rank: 2, neighborhood: "Beşiktaş", seasonId: "s1", territoriesOwned: 22),
            LeaderboardEntry(id: "3", userId: "u3", displayName: "Third Place", photoURL: nil, color: "#45B7D1", trail: 12000, rank: 3, neighborhood: "Şişli", seasonId: "s1", territoriesOwned: 15),
            LeaderboardEntry(id: "4", userId: "u4", displayName: "Fourth", photoURL: nil, color: "#96CEB4", trail: 8000, rank: 4, neighborhood: "Bakırköy", seasonId: "s1", territoriesOwned: 10),
        ],
        currentUserId: "u2"
    )
}
