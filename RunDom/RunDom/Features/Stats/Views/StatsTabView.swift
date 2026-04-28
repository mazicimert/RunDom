import SwiftUI

struct StatsTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var unitPreference: UnitPreference
    @StateObject private var statsVM = StatsViewModel()
    @StateObject private var historyVM = RunHistoryViewModel()
    @StateObject private var reportVM = WeeklyReportViewModel()
    @StateObject private var heatmapViewModel = CalendarHeatmapViewModel()

    @State private var selectedRun: RunSession?
    @State private var pendingDeleteRun: RunSession?
    @State private var showDeleteConfirmation = false
    @State private var deleteErrorMessage: String?
    @State private var hasCompletedInitialLoad = false
    @State private var selectedTrailPoint: ChartDataPoint?
    @State private var selectedDistancePoint: ChartDataPoint?

    var body: some View {
        Group {
            if shouldShowInitialLoading {
                skeletonContent
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        RunCalendarHeatmapView(viewModel: heatmapViewModel)
                            .padding(.horizontal, AppConstants.UI.screenPadding)
                            .padding(.vertical, 12)

                        // Period Picker
                        Picker("", selection: $statsVM.period) {
                            ForEach(StatsPeriod.allCases, id: \.self) { period in
                                Text(period.localized)
                                    .tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .screenPadding()

                        Text(statsVM.periodSummaryText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
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

                        AIWeeklyAnalysisLauncher()
                            .screenPadding()

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
        .onChange(of: statsVM.period) { _ in
            selectedTrailPoint = nil
            selectedDistancePoint = nil
        }
        .onChange(of: statsVM.runs) { _ in
            rebuildHeatmap()
        }
        .onChange(of: unitPreference.useMiles) { _ in
            rebuildHeatmap()
        }
        .onAppear {
            rebuildHeatmap()
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
        VStack(spacing: 12) {
            StatCardView(
                icon: "flame.fill",
                value: statsVM.heroTrailText,
                label: "stats.totalTrail".localized,
                iconColor: .orange,
                variant: .hero,
                supportingText: statsVM.period.localized,
                detailText: statsVM.trailDeltaText,
                detailColor: statsVM.trailDeltaSummary.tone.color
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                StatCardView(
                    icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                    value: statsVM.totalDistanceCompactText,
                    label: "stats.totalDistance".localized,
                    iconColor: .green,
                    variant: .compact
                )
                StatCardView(
                    icon: "figure.run",
                    value: "\(statsVM.totalRunsCount)",
                    label: "profile.totalRuns".localized,
                    iconColor: .blue,
                    variant: .compact
                )
                StatCardView(
                    icon: "hexagon.fill",
                    value: "\(statsVM.totalTerritories)",
                    label: "run.territories".localized,
                    iconColor: .purple,
                    variant: .compact
                )
            }
        }
        .screenPadding()
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        TrailChartView(
            title: "stats.trailChart".localized,
            data: statsVM.chartData,
            style: .bar,
            accentColor: .orange,
            insightText: statsVM.trailDeltaText,
            insightColor: statsVM.trailDeltaSummary.tone.color,
            valueFormatter: { "\($0.formattedTrail) \("trail.unit".localized)" },
            axisValueFormatter: { $0.formattedTrail },
            selectedPoint: $selectedTrailPoint
        )
        .screenPadding()
    }

    // MARK: - Distance Chart Section

    private var distanceChartSection: some View {
        TrailChartView(
            title: "stats.distanceChart".localized,
            data: statsVM.distanceChartData,
            style: .lineArea,
            accentColor: .green,
            insightText: statsVM.distanceDeltaText,
            insightColor: statsVM.distanceDeltaSummary.tone.color,
            valueFormatter: { value in
                let convertedValue = UnitPreference.distanceValue(
                    fromKilometers: value,
                    useMiles: unitPreference.useMiles
                )
                return "\(convertedValue.formattedDecimal(maxFractionDigits: 1, minFractionDigits: 1)) \(unitPreference.distanceUnitLabel)"
            },
            axisValueFormatter: { value in
                let convertedValue = UnitPreference.distanceValue(
                    fromKilometers: value,
                    useMiles: unitPreference.useMiles
                )
                return convertedValue.formattedDecimal(maxFractionDigits: 1)
            },
            selectedPoint: $selectedDistancePoint
        )
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

                Text("stats.periodSummary.loading".localized)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .screenPadding()

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
        VStack(spacing: 12) {
            StatsSkeletonHeroCard()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                StatsSkeletonCard()
                StatsSkeletonCard()
                StatsSkeletonCard()
            }
        }
        .screenPadding()
    }

    private func skeletonChartSection(title: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    StatsSkeletonBlock(width: 140, height: 12)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    StatsSkeletonBlock(width: 62, height: 14)
                    StatsSkeletonBlock(width: 76, height: 10)
                }
            }

            StatsSkeletonChart()
        }
        .padding(AppConstants.UI.cardPadding)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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

            VStack(spacing: 12) {
                StatsSkeletonHistoryRow()
                StatsSkeletonHistoryRow()
                StatsSkeletonHistoryRow()
            }
            .screenPadding()
        }
    }

    private func reloadAll(userId: String) async {
        async let stats: () = statsVM.loadStats(userId: userId)
        async let history: () = historyVM.loadRuns(userId: userId)
        async let reports: () = reportVM.loadReports(userId: userId)
        _ = await (stats, history, reports)
    }

    private func rebuildHeatmap() {
        heatmapViewModel.buildHeatmap(
            from: statsVM.allRuns,
            streakDays: statsVM.currentStreakDays
        )
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
        VStack(alignment: .leading, spacing: 12) {
            Circle()
                .fill(Color.secondary.opacity(0.16))
                .frame(width: 34, height: 34)

            Spacer(minLength: 0)

            StatsSkeletonBlock(width: 54, height: 18)
            StatsSkeletonBlock(width: 46, height: 10)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .padding(14)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct StatsSkeletonHeroCard: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardBackground)

            Circle()
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 180, height: 180)
                .blur(radius: 24)
                .offset(x: 180, y: -20)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    StatsSkeletonBlock(width: 110, height: 32)
                    Spacer()
                    StatsSkeletonBlock(width: 88, height: 28)
                }

                StatsSkeletonBlock(width: 132, height: 42)
                StatsSkeletonBlock(width: 86, height: 14)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 172, alignment: .leading)
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
                    .shimmer()
            }
        }
        .frame(height: 180, alignment: .bottom)
    }
}

private struct StatsSkeletonHistoryRow: View {
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.16))
                .frame(width: 114, height: 104)
                .shimmer()

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    StatsSkeletonBlock(width: 58, height: 28)

                    Spacer()

                    StatsSkeletonBlock(width: 52, height: 28)
                    StatsSkeletonBlock(width: 8, height: 12)
                        .padding(.top, 8)
                }

                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        StatsSkeletonBlock(width: 64, height: 18)
                        StatsSkeletonBlock(width: 42, height: 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        StatsSkeletonBlock(width: 52, height: 18)
                        StatsSkeletonBlock(width: 34, height: 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        StatsSkeletonBlock(width: 66, height: 18)
                        StatsSkeletonBlock(width: 48, height: 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(10)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct StatsSkeletonBlock: View {
    let width: CGFloat?
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.secondary.opacity(0.16))
            .frame(width: width, height: height)
            .shimmer()
    }
}
