import SwiftUI

struct LeaderboardTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: LeaderboardViewModel

    init(locationManager: LocationManager) {
        _viewModel = StateObject(wrappedValue: LeaderboardViewModel(locationManager: locationManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            LeaderboardFilterCard(
                selectedPeriod: viewModel.period,
                selectedScope: viewModel.scope,
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
                LeaderboardEmptyStateView(onStartRun: { router.selectedTab = .run })
                    .screenPadding()
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
            .environmentObject(AppRouter())
    }
}

// MARK: - Filter Card

private struct LeaderboardFilterCard: View {
    let selectedPeriod: LeaderboardPeriod
    let selectedScope: LeaderboardScope
    let onPeriodSelected: (LeaderboardPeriod) -> Void
    let onScopeSelected: (LeaderboardScope) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("leaderboard.activeBoard".localized)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Spacer(minLength: 8)

                if selectedPeriod == .weekly {
                    WeeklySeasonCountdownPill()
                        .transition(.opacity.combined(with: .scale))
                }
            }

            VStack(spacing: 8) {
                LeaderboardSegmentedControl(
                    options: LeaderboardPeriod.allCases,
                    selection: selectedPeriod,
                    title: title(for:),
                    icon: icon(for:),
                    onSelect: onPeriodSelected
                )

                LeaderboardSegmentedControl(
                    options: LeaderboardScope.allCases,
                    selection: selectedScope,
                    title: title(for:),
                    icon: icon(for:),
                    onSelect: onScopeSelected
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: selectedPeriod)
    }

    private func title(for period: LeaderboardPeriod) -> String {
        switch period {
        case .weekly: return "leaderboard.period.weekly".localized
        case .allTime: return "leaderboard.period.allTime".localized
        }
    }

    private func icon(for period: LeaderboardPeriod) -> String {
        switch period {
        case .weekly: return "calendar"
        case .allTime: return "infinity"
        }
    }

    private func title(for scope: LeaderboardScope) -> String {
        switch scope {
        case .global: return "leaderboard.global".localized
        case .neighborhood: return "leaderboard.neighborhood".localized
        }
    }

    private func icon(for scope: LeaderboardScope) -> String {
        switch scope {
        case .global: return "globe"
        case .neighborhood: return "mappin.circle"
        }
    }
}

// MARK: - Segmented Control

private struct LeaderboardSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let title: (Option) -> String
    let icon: (Option) -> String
    let onSelect: (Option) -> Void

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    onSelect(option)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: icon(option))
                            .font(.system(size: 11, weight: .semibold))
                        Text(title(option))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .matchedGeometryEffect(id: "segment", in: namespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(
            Capsule().fill(Color(uiColor: .systemBackground).opacity(0.55))
        )
        .animation(.easeInOut(duration: 0.2), value: selection)
    }
}

// MARK: - Countdown Pill

private struct WeeklySeasonCountdownPill: View {
    private let seasonService = SeasonService()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let remaining = max(seasonService.generateCurrentSeason().endDate.timeIntervalSince(context.date), 0)

            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 0) {
                    Text("leaderboard.weekly.endsIn".localized)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(formatRemaining(remaining))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.accentColor.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
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

// MARK: - Pinned Current User Card

private struct LeaderboardPinnedCurrentUserCard: View {
    let entry: LeaderboardEntry

    private var userColor: Color {
        Color(hex: entry.color) ?? .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("leaderboard.you".localized, systemImage: "figure.run")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)

                Spacer()

                Text("leaderboard.pinned.title".localized)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            LeaderboardRowView(entry: entry, isCurrentUser: true)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.5), userColor.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.accentColor.opacity(0.22), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Empty State (screen-specific)

private struct LeaderboardEmptyStateView: View {
    let onStartRun: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .overlay(
                        Circle().stroke(Color.accentColor.opacity(0.14), lineWidth: 1)
                    )

                Image(systemName: "trophy.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                    )
            }
            .frame(width: 116, height: 116)
            .overlay(alignment: .bottomTrailing) {
                // Runner badge anchored cleanly to the medallion's rim
                Image(systemName: "figure.run")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 3))
                    .offset(x: 4, y: 4)
            }

            VStack(spacing: 8) {
                Text("leaderboard.empty".localized)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text("leaderboard.empty.subtitle".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onStartRun) {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.subheadline.weight(.bold))
                    Text("leaderboard.empty.cta".localized)
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                )
                .shadow(color: Color.accentColor.opacity(0.22), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }
}

#Preview("Empty") {
    LeaderboardEmptyStateView(onStartRun: {})
        .preferredColorScheme(.dark)
}
