import SwiftUI

struct SocialTabView: View {
    let locationManager: LocationManager

    @EnvironmentObject private var appState: AppState
    @State private var segment: Segment = .feed
    @State private var showSharePicker = false

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
        .toolbar {
            if segment == .feed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSharePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("social.share.picker.open".localized)
                }
            }
        }
        .sheet(isPresented: $showSharePicker) {
            SharePastRunPickerView()
                .environmentObject(appState)
        }
    }
}
