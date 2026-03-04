import SwiftUI

struct BadgeDetailView: View {
    let badge: Badge
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Badge Icon
                ZStack {
                    Circle()
                        .fill(badge.isUnlocked ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                        .frame(width: 100, height: 100)

                    Image(systemName: badge.iconName)
                        .font(.system(size: 44))
                        .foregroundStyle(badge.isUnlocked ? Color.accentColor : Color.secondary)
                }
                .padding(.top, 20)

                // Badge Name
                Text(badge.localizedName)
                    .font(.title2.bold())

                // Badge Description
                Text(badge.localizedDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppConstants.UI.screenPadding)

                // Category
                Text("badge.category.\(badge.category.rawValue)".localized)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())

                // Progress or Unlock Date
                if badge.isUnlocked {
                    if let date = badge.unlockedAt {
                        Label(date.formatted(style: .medium), systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                } else {
                    VStack(spacing: 8) {
                        ProgressView(value: badge.progressPercentage)
                            .tint(.accentColor)
                            .frame(width: 200)

                        Text("\(Int(badge.progress)) / \(Int(badge.targetValue))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .navigationTitle("profile.badges".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    BadgeDetailView(badge: Badge(
        id: "1",
        nameKey: "First Run",
        descriptionKey: "Complete your first run",
        iconName: "figure.run",
        category: .performance,
        isSecret: false,
        isUnlocked: true,
        unlockedAt: Date()
    ))
}
