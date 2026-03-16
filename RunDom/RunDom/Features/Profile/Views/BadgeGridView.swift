import SwiftUI

struct BadgeGridView: View {
    let badges: [Badge]
    var onBadgeTap: ((Badge) -> Void)? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 16)
    ]

    var body: some View {
        if badges.isEmpty {
            EmptyStateView(
                icon: "rosette",
                title: "profile.noBadges".localized,
                subtitle: "profile.noBadges.subtitle".localized
            )
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(badges) { badge in
                    BadgeCell(badge: badge)
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

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 56, height: 56)

                if badge.isSecret && !badge.isUnlocked {
                    Image(systemName: "questionmark")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: badge.iconName)
                        .font(.title2)
                        .foregroundStyle(badge.isUnlocked ? Color.accentColor : Color.secondary)
                }
            }

            Text(badge.isSecret && !badge.isUnlocked ? "badge.secret".localized : badge.localizedName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(badge.isUnlocked ? .primary : .secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)

            if !badge.isUnlocked && !badge.isSecret {
                ProgressView(value: badge.progressPercentage)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .frame(width: 50)
            }
        }
        .frame(width: 80)
        .opacity(badge.isUnlocked ? 1.0 : 0.6)
    }
}

#Preview {
    BadgeGridView(badges: [
        Badge(id: "1", nameKey: "First Run", descriptionKey: "Complete first run", iconName: "figure.run", category: .performance, isSecret: false, isUnlocked: true),
        Badge(id: "2", nameKey: "5K Runner", descriptionKey: "Run 5km", iconName: "medal.fill", category: .performance, isSecret: false, isUnlocked: false, progress: 3.2, targetValue: 5.0),
        Badge(id: "3", nameKey: "Secret", descriptionKey: "Hidden", iconName: "star.fill", category: .exploration, isSecret: true)
    ])
    .padding()
}
