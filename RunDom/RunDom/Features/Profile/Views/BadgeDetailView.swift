import SwiftUI

struct BadgeDetailView: View {
    let badge: Badge
    @Environment(\.dismiss) private var dismiss
    private var isHiddenSecret: Bool { badge.isSecret && !badge.isUnlocked }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(badge.isUnlocked ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                            .frame(width: 108, height: 108)

                        Image(systemName: isHiddenSecret ? "questionmark" : badge.iconName)
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(badge.isUnlocked ? Color.accentColor : Color.secondary)
                    }
                    .padding(.top, 12)

                    Text(isHiddenSecret ? "badge.secret".localized : badge.localizedName)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text(isHiddenSecret ? "badge.locked".localized : badge.localizedDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("badge.category.\(badge.category.rawValue)".localized)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())

                    if badge.isUnlocked {
                        VStack(spacing: 8) {
                            Label("badge.completed".localized, systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)

                            if let date = badge.unlockedAt {
                                Text(date.formatted(style: .medium))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        VStack(spacing: 10) {
                            ProgressView(value: badge.progressPercentage)
                                .tint(.accentColor)
                                .progressViewStyle(.linear)

                            HStack {
                                Text(badge.progressText)
                                    .font(.caption.weight(.medium))

                                Spacer()

                                Text("\("badge.remaining".localized): \(badge.remainingText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.bottom, 24)
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
