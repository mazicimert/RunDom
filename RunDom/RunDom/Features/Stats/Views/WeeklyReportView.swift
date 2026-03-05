import SwiftUI

struct WeeklyReportView: View {
    let report: WeeklyReport

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text("stats.weeklyReport".localized)
                        .font(.title2.bold())

                    Text("stats.week".localized(with: report.weekNumber, report.year))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                // Summary Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCardView(
                        icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                        value: report.totalDistance.formattedDistance,
                        label: "stats.totalDistance".localized,
                        iconColor: .green
                    )
                    StatCardView(
                        icon: "flame.fill",
                        value: report.totalTrail.formattedTrail,
                        label: "stats.totalTrail".localized,
                        iconColor: .orange
                    )
                    StatCardView(
                        icon: "figure.run",
                        value: "\(report.totalRuns)",
                        label: "profile.totalRuns".localized,
                        iconColor: .blue
                    )
                    StatCardView(
                        icon: "speedometer",
                        value: report.avgSpeed.formattedSpeed,
                        label: "run.avgSpeed".localized,
                        iconColor: .purple
                    )
                }
                .screenPadding()

                // Week over Week Change
                HStack {
                    Image(systemName: report.weekOverWeekChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(report.weekOverWeekChange >= 0 ? .green : .red)

                    Text(report.weekOverWeekChange.formattedPercentChange)
                        .font(.headline)
                        .foregroundStyle(report.weekOverWeekChange >= 0 ? .green : .red)

                    Text("stats.weekOverWeek".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .cardStyle()
                .screenPadding()

                // Territories
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("+\(report.territoriesGained)")
                            .font(.title3.bold())
                            .foregroundStyle(.green)
                        Text("stats.gained".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 40)

                    VStack(spacing: 4) {
                        Text("-\(report.territoriesLost)")
                            .font(.title3.bold())
                            .foregroundStyle(.red)
                        Text("stats.lost".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 40)

                    VStack(spacing: 4) {
                        let net = report.netTerritories
                        Text("\(net >= 0 ? "+" : "")\(net)")
                            .font(.title3.bold())
                            .foregroundStyle(net >= 0 ? .green : .red)
                        Text("stats.net".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .cardStyle()
                .screenPadding()

                // Rankings
                if report.globalRank != nil || report.neighborhoodRank != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("stats.rankings".localized)
                            .font(.headline)

                        if let globalRank = report.globalRank {
                            HStack {
                                Label("leaderboard.global".localized, systemImage: "globe")
                                Spacer()
                                Text("#\(globalRank)")
                                    .font(.headline.monospacedDigit())
                            }
                        }

                        if let neighborhoodRank = report.neighborhoodRank {
                            HStack {
                                Label("leaderboard.neighborhood".localized, systemImage: "mappin.circle")
                                Spacer()
                                Text("#\(neighborhoodRank)")
                                    .font(.headline.monospacedDigit())
                            }
                        }
                    }
                    .cardStyle()
                    .screenPadding()
                }

                // Longest Run
                HStack {
                    Label("stats.longestRun".localized, systemImage: "arrow.right")
                    Spacer()
                    Text(report.longestRun.formattedDistance)
                        .font(.headline)
                }
                .cardStyle()
                .screenPadding()
            }
        }
        .navigationTitle("stats.weeklyReport".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        WeeklyReportView(report: WeeklyReport(
            id: "1", userId: "u1", seasonId: "s1",
            weekNumber: 10, year: 2026,
            totalDistance: 28.5, totalTrail: 4200,
            totalRuns: 5, territoriesGained: 35,
            territoriesLost: 12, avgSpeed: 11.2,
            longestRun: 8.3, previousWeekTrail: 3500,
            globalRank: 42, neighborhoodRank: 5,
            createdAt: Date()
        ))
    }
}
