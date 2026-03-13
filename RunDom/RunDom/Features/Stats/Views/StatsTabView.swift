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
        .navigationTitle("tab.stats".localized)
        .onAppear {
            guard let userId = appState.currentUser?.id else { return }
            Task { await reloadAll(userId: userId) }
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
