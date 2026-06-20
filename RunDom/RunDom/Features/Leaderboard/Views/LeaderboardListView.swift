import SwiftUI

struct LeaderboardListView: View {
    let entries: [LeaderboardEntry]
    let currentUserId: String?

    var body: some View {
        let podium = Array(entries.prefix(3))

        VStack(spacing: 0) {
            // Podium (top 3) — the arena stage
            if !podium.isEmpty {
                PodiumView(entries: podium, currentUserId: currentUserId)
                    .padding(.bottom, 24)
            }

            // Remaining entries
            if entries.count > 3 {
                LazyVStack(spacing: 10) {
                    ForEach(Array(entries.enumerated()).dropFirst(3), id: \.element.id) { index, entry in
                        let isCurrentUser = entry.userId == currentUserId
                        LeaderboardRowView(
                            entry: entry,
                            isCurrentUser: isCurrentUser,
                            pointsToPass: isCurrentUser ? gapToRankAbove(at: index) : nil
                        )
                        .background {
                            // Report the current user's row frame so the parent can
                            // hide the pinned card while this row is on-screen.
                            if isCurrentUser {
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: LeaderboardCurrentUserFrameKey.self,
                                        value: proxy.frame(in: .named(leaderboardScrollSpace))
                                    )
                                }
                            }
                        }
                    }
                }
                .screenPadding()
            }
        }
    }

    /// Points the entry must earn to overtake the entry directly above it in the loaded list.
    private func gapToRankAbove(at index: Int) -> Double? {
        guard index > 0, index < entries.count else { return nil }
        let gap = entries[index - 1].trail - entries[index].trail
        return gap > 0 ? gap : nil
    }
}

// MARK: - Podium View

private struct PodiumView: View {
    let entries: [LeaderboardEntry]
    let currentUserId: String?

    private var champion: LeaderboardEntry? { entries.first }

    private var championColor: Color {
        guard let champion else { return .accentColor }
        return Color(hex: champion.color) ?? .accentColor
    }

    var body: some View {
        ZStack {
            stageGlow

            HStack(alignment: .bottom, spacing: 10) {
                // 2nd place
                if entries.count > 1 {
                    podiumColumn(entry: entries[1], pedestalHeight: 78)
                }

                // 1st place — center stage
                if let champion {
                    podiumColumn(entry: champion, pedestalHeight: 110)
                }

                // 3rd place
                if entries.count > 2 {
                    podiumColumn(entry: entries[2], pedestalHeight: 58)
                }
            }
            .padding(.top, 28)
            .screenPadding()
        }
    }

    // MARK: Stage atmosphere

    private var stageGlow: some View {
        RadialGradient(
            colors: [championColor.opacity(0.30), championColor.opacity(0.05), .clear],
            center: .top,
            startRadius: 0,
            endRadius: 230
        )
        .blur(radius: 8)
        .allowsHitTesting(false)
    }

    // MARK: Column

    private func podiumColumn(entry: LeaderboardEntry, pedestalHeight: CGFloat) -> some View {
        let isChampion = entry.rank == 1
        let isCurrentUser = entry.userId == currentUserId
        let color = Color(hex: entry.color) ?? .accentColor

        return VStack(spacing: 8) {
            if isChampion {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .yellow.opacity(0.5), radius: 6)
                    .symbolEffect(.pulse, options: .repeating)
            }

            // Avatar — only the champion carries a halo glow
            ZStack {
                if isChampion {
                    Circle()
                        .fill(color)
                        .frame(width: 88, height: 88)
                        .blur(radius: 26)
                        .opacity(0.6)
                }

                AvatarView(
                    photoURL: entry.photoURL,
                    userColor: entry.color,
                    size: isChampion ? 70 : 54
                )

                // Rank badge clinging to the avatar
                rankBadge(for: entry.rank)
                    .offset(y: isChampion ? 40 : 30)
            }

            Text(entry.displayName)
                .font(isChampion ? .subheadline.bold() : .caption.bold())
                .lineLimit(1)
                .padding(.top, isChampion ? 6 : 2)

            if isChampion {
                Text("leaderboard.champion".localized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(championColor)
                    .textCase(.uppercase)
                    .tracking(1)
            } else if isCurrentUser {
                Text("leaderboard.you".localized)
                    .font(.caption2.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.16), in: Capsule())
            }

            HStack(spacing: 4) {
                Text(entry.trail.formattedTrail)
                    .font(.caption.bold().monospacedDigit())
                Text("trail.unit".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if entry.territoriesOwned > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "hexagon.fill").font(.system(size: 7))
                    Text("leaderboard.territories".localized(with: entry.territoriesOwned))
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
            }

            pedestal(height: pedestalHeight, rank: entry.rank, color: color)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func pedestal(height: CGFloat, rank: Int, color: Color) -> some View {
        let isChampion = rank == 1
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(isChampion ? 0.42 : 0.26),
                            Color(uiColor: .secondarySystemBackground)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    // Lit top edge of the stage — territory color, consistent for every place
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(color.opacity(isChampion ? 0.55 : 0.4), lineWidth: 1)
                )

            Text("\(rank)")
                .font(.system(size: isChampion ? 34 : 26, weight: .heavy, design: .rounded))
                .foregroundStyle(color.opacity(0.9))
                .padding(.top, 8)
        }
        .frame(height: height)
        // Only the champion's stage casts a glow
        .shadow(color: isChampion ? color.opacity(0.3) : .clear, radius: 12, x: 0, y: 6)
        .padding(.top, 4)
    }

    private func rankBadge(for rank: Int) -> some View {
        Text("\(rank)")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Circle().fill(medalColor(for: rank)))
            .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
    }

    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.7)
        case 3: return .orange
        default: return .secondary
        }
    }
}

#Preview("Full") {
    ScrollView {
        LeaderboardListView(
            entries: [
                LeaderboardEntry(id: "1", userId: "u1", displayName: "Champion", photoURL: nil, color: "#FF6B6B", trail: 25000, rank: 1, neighborhood: "Kadıköy", seasonId: "s1", territoriesOwned: 30),
                LeaderboardEntry(id: "2", userId: "u2", displayName: "Runner Up", photoURL: nil, color: "#4ECDC4", trail: 18500, rank: 2, neighborhood: "Beşiktaş", seasonId: "s1", territoriesOwned: 22),
                LeaderboardEntry(id: "3", userId: "u3", displayName: "Third Place", photoURL: nil, color: "#45B7D1", trail: 12000, rank: 3, neighborhood: "Şişli", seasonId: "s1", territoriesOwned: 15),
                LeaderboardEntry(id: "4", userId: "u4", displayName: "Fourth", photoURL: nil, color: "#96CEB4", trail: 8000, rank: 4, neighborhood: "Bakırköy", seasonId: "s1", territoriesOwned: 10),
                LeaderboardEntry(id: "5", userId: "u5", displayName: "You", photoURL: nil, color: "#FFD166", trail: 6400, rank: 5, neighborhood: "Üsküdar", seasonId: "s1", territoriesOwned: 6),
            ],
            currentUserId: "u5"
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Two") {
    LeaderboardListView(
        entries: [
            LeaderboardEntry(id: "1", userId: "u1", displayName: "Champion", photoURL: nil, color: "#FF6B6B", trail: 25000, rank: 1, neighborhood: "Kadıköy", seasonId: "s1", territoriesOwned: 30),
            LeaderboardEntry(id: "2", userId: "u2", displayName: "Runner Up", photoURL: nil, color: "#4ECDC4", trail: 18500, rank: 2, neighborhood: "Beşiktaş", seasonId: "s1", territoriesOwned: 22),
        ],
        currentUserId: "u2"
    )
    .preferredColorScheme(.dark)
}

#Preview("One") {
    LeaderboardListView(
        entries: [
            LeaderboardEntry(id: "1", userId: "u1", displayName: "Champion", photoURL: nil, color: "#FF6B6B", trail: 25000, rank: 1, neighborhood: "Kadıköy", seasonId: "s1", territoriesOwned: 30),
        ],
        currentUserId: "u1"
    )
    .preferredColorScheme(.dark)
}
