import SwiftUI

struct LeaderboardTabView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: LeaderboardViewModel

    init(locationManager: LocationManager) {
        _viewModel = StateObject(wrappedValue: LeaderboardViewModel(locationManager: locationManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            LeaderboardFilterCard(
                selectedPeriod: viewModel.period,
                selectedScope: viewModel.scope,
                contextHeadline: viewModel.contextHeadline,
                contextDescription: viewModel.contextDescription,
                onPeriodSelected: { period in
                    Task { await viewModel.switchPeriod(to: period, currentUser: appState.currentUser) }
                },
                onScopeSelected: { scope in
                    Task { await viewModel.switchScope(to: scope, currentUser: appState.currentUser) }
                }
            )
            .screenPadding()
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Content
            if viewModel.isLoading {
                Spacer()
                LoadingView()
                Spacer()
            } else if viewModel.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "trophy",
                    title: "leaderboard.empty".localized,
                    subtitle: "leaderboard.empty.subtitle".localized
                )
                Spacer()
            } else {
                ScrollView {
                    LeaderboardListView(
                        entries: viewModel.entries,
                        currentUserId: appState.currentUser?.id
                    )
                    .padding(.bottom)
                }
            }
        }
        .navigationTitle("tab.leaderboard".localized)
        .task {
            await viewModel.loadLeaderboard(currentUser: appState.currentUser)
        }
        .refreshable {
            await viewModel.loadLeaderboard(currentUser: appState.currentUser)
        }
        .safeAreaInset(edge: .bottom) {
            if let pinnedEntry = pinnedCurrentUserEntry {
                LeaderboardPinnedCurrentUserCard(entry: pinnedEntry)
                    .screenPadding()
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
        }
    }

    private var pinnedCurrentUserEntry: LeaderboardEntry? {
        guard !viewModel.isLoading,
              let entry = viewModel.currentUserEntry,
              entry.rank > 3 else {
            return nil
        }

        return entry
    }
}

#Preview {
    NavigationStack {
        LeaderboardTabView(locationManager: LocationManager())
            .environmentObject(AppState())
    }
}

private struct LeaderboardFilterCard: View {
    let selectedPeriod: LeaderboardPeriod
    let selectedScope: LeaderboardScope
    let contextHeadline: String
    let contextDescription: String
    let onPeriodSelected: (LeaderboardPeriod) -> Void
    let onScopeSelected: (LeaderboardScope) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text("leaderboard.activeBoard".localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    WeeklySeasonCountdownPill()
                        .opacity(selectedPeriod == .weekly ? 1 : 0)
                }

                Text(contextHeadline)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(contextDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(minHeight: 32, alignment: .top)
            }

            HStack(spacing: 10) {
                ForEach(LeaderboardPeriod.allCases, id: \.rawValue) { period in
                    filterChip(
                        title: title(for: period),
                        icon: icon(for: period),
                        isSelected: selectedPeriod == period
                    ) {
                        onPeriodSelected(period)
                    }
                }
            }

            HStack(spacing: 10) {
                ForEach(LeaderboardScope.allCases, id: \.rawValue) { scope in
                    filterChip(
                        title: title(for: scope),
                        icon: icon(for: scope),
                        isSelected: selectedScope == scope
                    ) {
                        onScopeSelected(scope)
                    }
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
                    Color(uiColor: .secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func filterChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(uiColor: .systemBackground).opacity(0.68))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func title(for period: LeaderboardPeriod) -> String {
        switch period {
        case .weekly:
            return "leaderboard.period.weekly".localized
        case .allTime:
            return "leaderboard.period.allTime".localized
        }
    }

    private func icon(for period: LeaderboardPeriod) -> String {
        switch period {
        case .weekly:
            return "calendar"
        case .allTime:
            return "infinity"
        }
    }

    private func title(for scope: LeaderboardScope) -> String {
        switch scope {
        case .global:
            return "leaderboard.global".localized
        case .neighborhood:
            return "leaderboard.neighborhood".localized
        }
    }

    private func icon(for scope: LeaderboardScope) -> String {
        switch scope {
        case .global:
            return "globe"
        case .neighborhood:
            return "mappin.circle"
        }
    }
}

private struct WeeklySeasonCountdownPill: View {
    private let seasonService = SeasonService()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let remaining = max(seasonService.generateCurrentSeason().endDate.timeIntervalSince(context.date), 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text("leaderboard.weekly.endsIn".localized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(formatRemaining(remaining))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemBackground).opacity(0.72), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func formatRemaining(_ interval: TimeInterval) -> String {
        let totalMinutes = max(Int(interval / 60), 0)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "leaderboard.weekly.remaining.daysHours".localized(with: days, hours)
        }

        if hours > 0 {
            return "leaderboard.weekly.remaining.hoursMinutes".localized(with: hours, minutes)
        }

        return "leaderboard.weekly.remaining.minutes".localized(with: max(minutes, 1))
    }
}

private struct LeaderboardPinnedCurrentUserCard: View {
    let entry: LeaderboardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("leaderboard.you".localized, systemImage: "person.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                Text("leaderboard.pinned.title".localized)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            LeaderboardRowView(entry: entry, isCurrentUser: true)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 6)
    }
}
