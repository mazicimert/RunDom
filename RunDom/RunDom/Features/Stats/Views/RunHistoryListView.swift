import SwiftUI

struct RunHistoryListView: View {
    let runs: [RunSession]
    let hasMore: Bool
    var onLoadMore: (() -> Void)? = nil
    var onSelectRun: ((RunSession) -> Void)? = nil
    var onDeleteRun: ((RunSession) -> Void)? = nil

    var body: some View {
        if runs.isEmpty {
            EmptyStateView(
                icon: "figure.run",
                title: "stats.noRuns".localized,
                subtitle: "stats.noRuns.subtitle".localized
            )
        } else {
            LazyVStack(spacing: 0) {
                ForEach(runs) { run in
                    RunHistoryRow(
                        run: run,
                        onDelete: onDeleteRun.map { delete in
                            { delete(run) }
                        }
                    )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.selection()
                            onSelectRun?(run)
                        }

                    if run.id != runs.last?.id {
                        Divider()
                            .padding(.leading, AppConstants.UI.screenPadding)
                    }
                }

                if hasMore {
                    ProgressView()
                        .padding()
                        .onAppear {
                            onLoadMore?()
                        }
                }
            }
        }
    }
}

// MARK: - Run History Row

private struct RunHistoryRow: View {
    let run: RunSession
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Mode icon
            ZStack {
                Circle()
                    .fill(run.mode == .boost ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: run.mode == .boost ? "bolt.fill" : "figure.run")
                    .font(.body)
                    .foregroundStyle(run.mode == .boost ? .orange : .blue)
            }

            // Run info
            VStack(alignment: .leading, spacing: 2) {
                Text(run.startDate.formatted(style: .medium))
                    .font(.subheadline.bold())

                HStack(spacing: 8) {
                    Label(run.distance.formattedDistanceFromMeters, systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    Label(run.duration.formattedDuration, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Trail earned
            VStack(alignment: .trailing, spacing: 2) {
                Text(run.trail.formattedTrail)
                    .font(.subheadline.bold().monospacedDigit())

                Text("trail.unit".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 52, alignment: .trailing)

            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.caption.bold())
                        Text("common.delete".localized)
                            .font(.caption2.bold())
                            .lineLimit(1)
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.red.opacity(0.35), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.delete".localized)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, AppConstants.UI.screenPadding)
    }
}

#Preview {
    RunHistoryListView(
        runs: [
            RunSession(id: "1", userId: "u1", mode: .normal, startDate: Date(), endDate: Date().addingTimeInterval(1800), distance: 5200, avgSpeed: 10.4, trail: 650, territoriesCaptured: 8),
            RunSession(id: "2", userId: "u1", mode: .boost, startDate: Date().addingTimeInterval(-86400), endDate: Date().addingTimeInterval(-84600), distance: 3100, avgSpeed: 12.0, trail: 890, territoriesCaptured: 5),
        ],
        hasMore: false
    )
}
