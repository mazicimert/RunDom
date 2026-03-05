import SwiftUI

struct StatsTabView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var statsVM = StatsViewModel()
    @StateObject private var historyVM = RunHistoryViewModel()
    @StateObject private var reportVM = WeeklyReportViewModel()

    @State private var selectedRun: RunSession?

    var body: some View {
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

                // Weekly Report Card
                if let report = reportVM.latestReport {
                    weeklyReportCard(report: report)
                }

                // Run History
                historySection
            }
            .padding(.vertical)
        }
        .navigationTitle("tab.stats".localized)
        .task {
            if let userId = appState.currentUser?.id {
                async let stats: () = statsVM.loadStats(userId: userId)
                async let history: () = historyVM.loadRuns(userId: userId)
                async let reports: () = reportVM.loadReports(userId: userId)
                _ = await (stats, history, reports)
            }
        }
        .refreshable {
            if let userId = appState.currentUser?.id {
                async let stats: () = statsVM.loadStats(userId: userId)
                async let history: () = historyVM.loadRuns(userId: userId)
                async let reports: () = reportVM.loadReports(userId: userId)
                _ = await (stats, history, reports)
            }
        }
        .navigationDestination(item: $selectedRun) { run in
            RunHistoryDetailView(run: run)
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
                value: statsVM.totalDistance.formattedDistance,
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
                }
            )
        }
    }
}

#Preview {
    NavigationStack {
        StatsTabView()
            .environmentObject(AppState())
    }
}
