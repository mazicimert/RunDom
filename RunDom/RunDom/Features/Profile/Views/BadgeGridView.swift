import SwiftUI

struct BadgeGridView: View {
    let badges: [Badge]
    var onBadgeTap: ((Badge) -> Void)? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 96), spacing: 20)
    ]

    var body: some View {
        if badges.isEmpty {
            EmptyStateView(
                icon: "rosette",
                title: "profile.noBadges".localized,
                subtitle: "profile.noBadges.subtitle".localized
            )
        } else {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(badges) { badge in
                    BadgeCell(badge: badge)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.selection()
                            onBadgeTap?(badge)
                        }
                }
            }
        }
    }
}

// MARK: - Badge Cell

private struct BadgeCell: View {
    let badge: Badge

    private let medallionSize: CGFloat = 70

    private var isHiddenSecret: Bool { badge.isSecret && !badge.isUnlocked }

    var body: some View {
        VStack(spacing: 10) {
            BadgeMedallion(
                badge: badge,
                size: medallionSize,
                iconSize: 26,
                ringWidth: 4
            )

            Text(isHiddenSecret ? "badge.secret".localized : badge.localizedName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(badge.isUnlocked ? .primary : .secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(height: 30, alignment: .top)
        }
        .frame(width: 96)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Shared Medallion

/// The circular badge artwork shared by the grid and the detail sheet so the
/// two stay visually in sync. Unlocked badges use a soft category-tinted
/// gradient with a check accent; locked badges show a progress ring.
struct BadgeMedallion: View {
    let badge: Badge
    var size: CGFloat = 70
    var iconSize: CGFloat = 26
    var ringWidth: CGFloat = 4

    private var tint: Color { badge.category.themeColor }
    private var isHiddenSecret: Bool { badge.isSecret && !badge.isUnlocked }

    var body: some View {
        ZStack {
            if badge.isUnlocked {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.9), tint.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: tint.opacity(0.35), radius: size * 0.14, x: 0, y: size * 0.08)
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: size, height: size)

                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: ringWidth)
                    .frame(width: size, height: size)

                if !isHiddenSecret && badge.progressPercentage > 0 {
                    Circle()
                        .trim(from: 0, to: badge.progressPercentage)
                        .stroke(
                            tint.opacity(0.85),
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: size, height: size)
                        .animation(.easeOut(duration: 0.4), value: badge.progressPercentage)
                }
            }

            Image(systemName: isHiddenSecret ? "questionmark" : badge.iconName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(badge.isUnlocked ? .white : Color.secondary)

            if badge.isUnlocked {
                checkAccent
                    .offset(x: size * 0.34, y: size * 0.34)
            }
        }
        .frame(width: size + size * 0.18, height: size + size * 0.18)
        .opacity(badge.isUnlocked ? 1.0 : 0.85)
    }

    private var checkAccent: some View {
        let dotSize = size * 0.3
        return Circle()
            .fill(Color.cardBackground)
            .frame(width: dotSize, height: dotSize)
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: dotSize * 0.55, weight: .bold))
                    .foregroundStyle(tint)
            )
            .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Category Theme Color

extension BadgeCategory {
    /// A distinct, controlled accent per category so the badge wall reads as
    /// lively but cohesive rather than a single flat accent color.
    var themeColor: Color {
        switch self {
        case .performance: return .orange
        case .territory: return .blue
        case .exploration: return .green
        case .streak: return .pink
        case .dropzone: return .purple
        }
    }
}

#Preview {
    BadgeGridView(badges: [
        Badge(id: "1", nameKey: "First Run", descriptionKey: "Complete first run", iconName: "figure.run", category: .performance, isSecret: false, isUnlocked: true),
        Badge(id: "2", nameKey: "5K Runner", descriptionKey: "Run 5km", iconName: "medal.fill", category: .performance, isSecret: false, isUnlocked: false, progress: 3.2, targetValue: 5.0),
        Badge(id: "3", nameKey: "Explorer", descriptionKey: "Explore", iconName: "map.fill", category: .exploration, isSecret: false, isUnlocked: true),
        Badge(id: "4", nameKey: "Streak", descriptionKey: "7 day streak", iconName: "flame.fill", category: .streak, isSecret: false, isUnlocked: false, progress: 4, targetValue: 7),
        Badge(id: "5", nameKey: "Secret", descriptionKey: "Hidden", iconName: "star.fill", category: .territory, isSecret: true)
    ])
    .padding()
}
