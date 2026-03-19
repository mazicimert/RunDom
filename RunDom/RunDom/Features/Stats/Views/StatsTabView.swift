import SwiftUI

struct StatsTabView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var statsVM = StatsViewModel()
    @StateObject private var historyVM = RunHistoryViewModel()
    @StateObject private var reportVM = WeeklyReportViewModel()

    @State private var selectedRun: RunSession?
    @State private var pendingDeleteRun: RunSession?
    @State private var showDeleteConfirmation = false
    @State private var deleteErrorMessage: String?
    @State private var hasCompletedInitialLoad = false

    var body: some View {
        Group {
            if shouldShowInitialLoading {
                skeletonContent
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Period Picker
                        Picker("", selection: $statsVM.period) {
                            ForEach(StatsPeriod.allCases, id: \.self) { period in
                                Text(period.localized)
                                    .tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .screenPadding()

                        // Summary Cards
                        summarySection

                        // Trail Chart
                        chartSection

                        // Distance Chart
                        distanceChartSection

                        // Weekly Report Card
                        if let report = reportVM.latestReport {
                            weeklyReportCard(report: report)
                        }

                        // Run History
                        historySection
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("tab.stats".localized)
        .task(id: appState.currentUser?.id) {
            guard let userId = appState.currentUser?.id else {
                hasCompletedInitialLoad = false
                return
            }

            hasCompletedInitialLoad = false
            await reloadAll(userId: userId)
            hasCompletedInitialLoad = true
        }
        .refreshable {
            guard let userId = appState.currentUser?.id else { return }
            await reloadAll(userId: userId)
        }
        .navigationDestination(item: $selectedRun) { run in
            RunHistoryDetailView(run: run)
        }
        .confirmationDialog(
            "run.delete.confirmTitle".localized,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("common.delete".localized, role: .destructive) {
                guard let run = pendingDeleteRun, let userId = appState.currentUser?.id else { return }
                Task {
                    do {
                        try await historyVM.deleteRun(run)
                        await reloadAll(userId: userId)
                    } catch {
                        deleteErrorMessage = "run.delete.failed".localized
                        AppLogger.firebase.error("Failed to delete run: \(error.localizedDescription)")
                    }
                    pendingDeleteRun = nil
                }
            }
            Button("common.cancel".localized, role: .cancel) {
                pendingDeleteRun = nil
            }
        } message: {
            Text("run.delete.confirmMessage".localized)
        }
        .alert(
            "common.error".localized,
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )
        ) {
            Button("common.ok".localized, role: .cancel) {
                deleteErrorMessage = nil
            }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCardView(
                icon: "flame.fill",
                value: statsVM.totalTrail.formattedTrail,
                label: "stats.totalTrail".localized,
                iconColor: .orange
            )
            StatCardView(
                icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                value: statsVM.totalDistanceText,
                label: "stats.totalDistance".localized,
                iconColor: .green
            )
            StatCardView(
                icon: "figure.run",
                value: "\(statsVM.totalRunsCount)",
                label: "profile.totalRuns".localized,
                iconColor: .blue
            )
            StatCardView(
                icon: "hexagon.fill",
                value: "\(statsVM.totalTerritories)",
                label: "run.territories".localized,
                iconColor: .purple
            )
        }
        .screenPadding()
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("stats.trailChart".localized)
                .font(.headline)

            TrailChartView(data: statsVM.chartData)
        }
        .cardStyle()
        .screenPadding()
    }

    // MARK: - Distance Chart Section

    private var distanceChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("stats.distanceChart".localized)
                .font(.headline)

            TrailChartView(data: statsVM.distanceChartData, barColor: .green)
        }
        .cardStyle()
        .screenPadding()
    }

    // MARK: - Weekly Report Card

    private func weeklyReportCard(report: WeeklyReport) -> some View {
        NavigationLink {
            WeeklyReportView(report: report)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("stats.weeklyReport".localized)
                        .font(.headline)

                    HStack(spacing: 4) {
                        Image(systemName: report.weekOverWeekChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(report.weekOverWeekChange.formattedPercentChange)
                    }
                    .font(.subheadline)
                    .foregroundStyle(report.weekOverWeekChange >= 0 ? .green : .red)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.quaternary)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
        .screenPadding()
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("stats.runHistory".localized)
                .font(.headline)
                .screenPadding()

            RunHistoryListView(
                runs: historyVM.runs,
                hasMore: historyVM.hasMore,
                onLoadMore: {
                    if let userId = appState.currentUser?.id {
                        Task { await historyVM.loadMore(userId: userId) }
                    }
                },
                onSelectRun: { run in
                    selectedRun = run
                },
                onDeleteRun: { run in
                    pendingDeleteRun = run
                    showDeleteConfirmation = true
                }
            )
        }
    }

    // MARK: - Data Reload

    private var shouldShowInitialLoading: Bool {
        !hasCompletedInitialLoad
    }

    private var skeletonContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                Picker("", selection: .constant(StatsPeriod.thisWeek)) {
                    ForEach(StatsPeriod.allCases, id: \.self) { period in
                        Text(period.localized)
                            .tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .screenPadding()
                .disabled(true)

                skeletonSummarySection
                skeletonChartSection(title: "stats.trailChart".localized)
                skeletonChartSection(title: "stats.distanceChart".localized)
                skeletonWeeklyReportSection
                skeletonHistorySection
            }
            .padding(.vertical)
        }
        .allowsHitTesting(false)
    }

    private var skeletonSummarySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatsSkeletonCard()
            StatsSkeletonCard()
            StatsSkeletonCard()
            StatsSkeletonCard()
        }
        .screenPadding()
    }

    private func skeletonChartSection(title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            StatsSkeletonChart()
        }
        .cardStyle()
        .screenPadding()
    }

    private var skeletonWeeklyReportSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                StatsSkeletonBlock(width: 120, height: 18)
                StatsSkeletonBlock(width: 92, height: 14)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.quaternary)
        }
        .cardStyle()
        .screenPadding()
    }

    private var skeletonHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("stats.runHistory".localized)
                .font(.headline)
                .screenPadding()

            VStack(spacing: 0) {
                StatsSkeletonHistoryRow()
                Divider()
                    .padding(.leading, AppConstants.UI.screenPadding)
                StatsSkeletonHistoryRow()
                Divider()
                    .padding(.leading, AppConstants.UI.screenPadding)
                StatsSkeletonHistoryRow()
            }
        }
    }

    private func reloadAll(userId: String) async {
        async let stats: () = statsVM.loadStats(userId: userId)
        async let history: () = historyVM.loadRuns(userId: userId)
        async let reports: () = reportVM.loadReports(userId: userId)
        _ = await (stats, history, reports)
    }
}

#Preview {
    NavigationStack {
        StatsTabView()
            .environmentObject(AppState())
    }
}

private struct StatsSkeletonCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Color.secondary.opacity(0.16))
                .frame(width: 22, height: 22)

            StatsSkeletonBlock(width: 72, height: 22)
            StatsSkeletonBlock(width: 58, height: 12)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

private struct StatsSkeletonChart: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach([0.38, 0.64, 0.28, 0.82, 0.52, 0.7, 0.44], id: \.self) { ratio in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.secondary.opacity(0.16))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48 + (110 * ratio))
            }
        }
        .frame(height: 180, alignment: .bottom)
    }
}

private struct StatsSkeletonHistoryRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.secondary.opacity(0.16))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 8) {
                StatsSkeletonBlock(width: 110, height: 14)
                StatsSkeletonBlock(width: 140, height: 12)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                StatsSkeletonBlock(width: 52, height: 14)
                StatsSkeletonBlock(width: 36, height: 10)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, AppConstants.UI.screenPadding)
    }
}

private struct StatsSkeletonBlock: View {
    let width: CGFloat?
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.secondary.opacity(0.16))
            .frame(width: width, height: height)
    }
}
