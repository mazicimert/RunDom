import SwiftUI

struct BadgeDetailView: View {
    let badge: Badge
    @Environment(\.dismiss) private var dismiss
    private var isHiddenSecret: Bool { badge.isSecret && !badge.isUnlocked }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BadgeMedallion(
                        badge: badge,
                        size: 108,
                        iconSize: 44,
                        ringWidth: 6
                    )
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
                        .foregroundStyle(badge.category.themeColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(badge.category.themeColor.opacity(0.12))
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
                                .tint(badge.category.themeColor)
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
