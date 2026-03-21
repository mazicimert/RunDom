import SwiftUI

struct RunStatsOverlayView: View {
    let currentSpeed: Double
    let mode: RunMode
    let isBoostActive: Bool
    let distance: Double // km
    let elapsedTime: String
    let territories: Int

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            primaryMetric
                .frame(width: 138, alignment: .leading)

            divider

            secondaryStats
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.68))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.24), radius: 14, y: 8)
        )
    }

    private var primaryMetric: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("run.speedShort".localized)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .textCase(.uppercase)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", currentSpeed))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(speedColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("km/h")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            if mode == .boost {
                Text(boostStatusText)
                    .font(.caption2.bold())
                    .foregroundStyle(speedColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(speedColor.opacity(0.14), in: Capsule())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private var secondaryStats: some View {
        HStack(spacing: 12) {
            compactStat(value: elapsedTime, label: "run.timeShort".localized)
            compactStat(value: String(format: "%.2f", distance), label: "run.distanceShort".localized)
            compactStat(value: "\(territories)", label: "run.zonesShort".localized)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func compactStat(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .contentTransition(.numericText())

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
    }

    private var divider: some View {
        Capsule()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 64)
    }

    private var speedColor: Color {
        guard mode == .boost else { return .white }
        let threshold = AppConstants.Game.boostMinSpeedKmh
        if currentSpeed >= threshold + 2 {
            return .boostGreen
        } else if currentSpeed >= threshold {
            return .boostYellow
        }
        return .boostRed
    }

    private var boostStatusText: String {
        if !isBoostActive {
            return "run.boostCancelled".localized
        }
        let threshold = AppConstants.Game.boostMinSpeedKmh
        if currentSpeed >= threshold + 2 {
            return "run.boostSafe".localized
        } else if currentSpeed >= threshold {
            return "run.boostApproaching".localized
        }
        return String(format: "%.0f km/h %@", threshold, "run.boostRequired".localized)
    }
}
