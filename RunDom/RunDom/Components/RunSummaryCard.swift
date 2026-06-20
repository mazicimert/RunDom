import SwiftUI

/// Shared run "summary" card: route thumbnail on the left, points badge plus
/// distance / duration / pace metrics on the right, and a caller-supplied
/// trailing accessory (delete + chevron in run history, share state in the
/// feed run picker). Centralising the layout keeps the run history list and the
/// share picker visually identical instead of drifting into two designs.
struct RunSummaryCard<Accessory: View>: View {
    let run: RunSession
    /// Dims the whole card — used for runs that have already been shared.
    var isDimmed: Bool = false
    @ViewBuilder var accessory: () -> Accessory

    private let cardHeight: CGFloat = 124
    private let thumbnailSize = CGSize(width: 114, height: 104)

    var body: some View {
        HStack(spacing: 14) {
            RunHistoryRouteThumbnail(run: run, size: thumbnailSize)
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    pointsBadge

                    Spacer(minLength: 0)

                    accessory()
                }

                HStack(spacing: 10) {
                    metricColumn(
                        value: run.distance.formattedCompactDistanceValueFromMeters,
                        title: "run.distance".localized
                    )

                    metricColumn(
                        value: run.duration.formattedDuration,
                        title: "run.duration".localized
                    )

                    metricColumn(
                        value: run.avgSpeed.formattedPace,
                        unit: UnitPreference.shared.paceUnitLabel,
                        title: "run.avgPace".localized
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.cardBackground.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
        .opacity(isDimmed ? 0.55 : 1)
    }

    private var pointsBadge: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(run.trail.formattedTrail)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.primary)

            Text("trail.unit".localized)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func metricColumn(value: String, unit: String? = nil, title: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .layoutPriority(1)

                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .allowsTightening(true)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
