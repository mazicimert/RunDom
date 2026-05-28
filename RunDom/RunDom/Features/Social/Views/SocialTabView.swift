import SwiftUI

struct SocialTabView: View {
    let locationManager: LocationManager

    @State private var segment: Segment = .feed

    enum Segment: String, CaseIterable, Identifiable {
        case feed
        case leaderboard

        var id: String { rawValue }

        var title: String {
            switch self {
            case .feed: return "social.tab.feed".localized
            case .leaderboard: return "social.tab.leaderboard".localized
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $segment) {
                ForEach(Segment.allCases) { seg in
                    Text(seg.title).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppConstants.UI.screenPadding)
            .padding(.vertical, 10)

            Divider()
                .opacity(0.4)

            switch segment {
            case .feed:
                FeedView()
            case .leaderboard:
                LeaderboardTabView(locationManager: locationManager)
            }
        }
        .navigationTitle("tab.social".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}
