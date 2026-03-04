import SwiftUI

struct SpeedIndicatorView: View {
    let currentSpeed: Double
    let mode: RunMode
    let isBoostActive: Bool

    private var threshold: Double {
        AppConstants.Game.boostMinSpeedKmh
    }

    private var speedColor: Color {
        guard mode == .boost else { return .blue }
        if currentSpeed >= threshold + 2 {
            return .green
        } else if currentSpeed >= threshold {
            return .yellow
        }
        return .red
    }

    private var statusIcon: String {
        guard mode == .boost else { return "figure.run" }
        if currentSpeed >= threshold + 2 {
            return "checkmark.circle.fill"
        } else if currentSpeed >= threshold {
            return "exclamationmark.triangle.fill"
        }
        return "xmark.circle.fill"
    }

    var body: some View {
        VStack(spacing: 4) {
            // Speed value
            Text(String(format: "%.1f", currentSpeed))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(speedColor)

            Text("km/h")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Boost threshold indicator
            if mode == .boost {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .foregroundStyle(speedColor)
                        .font(.caption)

                    Text(boostStatusText)
                        .font(.caption2)
                        .foregroundStyle(speedColor)
                }
                .padding(.top, 4)

                if !isBoostActive {
                    Text("run.boostCancelled".localized)
                        .font(.caption2.bold())
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.UI.smallCornerRadius)
                .fill(.ultraThinMaterial)
        )
    }

    private var boostStatusText: String {
        if !isBoostActive {
            return "run.boostCancelled".localized
        }
        let diff = currentSpeed - threshold
        if diff >= 2 {
            return "run.boostSafe".localized
        } else if diff >= 0 {
            return "run.boostApproaching".localized
        }
        return String(format: "%.0f km/h %@", threshold, "run.boostRequired".localized)
    }
}
