import SwiftUI

/// Full badge wall, pushed from the profile's "See All" action. The profile
/// itself only shows a short preview; this screen lists every badge.
struct AllBadgesView: View {
    let badges: [Badge]
    let unlockedCount: Int

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !badges.isEmpty {
                    Text("\(unlockedCount)/\(badges.count)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                BadgeGridView(badges: badges) { badge in
                    router.presentedSheet = .badgeDetail(badge: badge)
                }
            }
            .screenPadding()
            .padding(.vertical, 16)
        }
        .navigationTitle("profile.badges".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}
