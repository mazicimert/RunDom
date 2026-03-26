import SwiftUI
import UIKit

struct RunStatsOverlayView: View {
    let currentSpeed: Double
    let avgSpeed: Double
    let maxSpeed: Double
    let pace: String
    let mode: RunMode
    let isBoostActive: Bool
    let distance: Double // km
    let elapsedTime: String
    let territories: Int
    let uniqueZones: Int
    let runState: ActiveRunViewModel.RunState
    let gpsSignalLost: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void

    @Binding var selectedDetent: PresentationDetent

    static let compactDetent: PresentationDetent = .fraction(0.35)
    static let expandedDetent: PresentationDetent = .fraction(0.85)

    private var isExpanded: Bool {
        selectedDetent == Self.expandedDetent
    }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                expandedContent
            } else {
                compactContent
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: runState)
    }

    // MARK: - Compact Layout

    private var compactContent: some View {
        VStack(spacing: 10) {
            gpsBadge
                .frame(maxWidth: .infinity, alignment: .trailing)

            heroMetricCompact
            secondaryStatsCompact

            if mode == .boost {
                boostStatusBadge
            }

            actionSection
        }
    }

    private var heroMetricCompact: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(currentSpeed.formattedCompactSpeedValue)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(speedColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("km/h")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(sheetSecondaryText)
                    .offset(y: -2)
            }

            Text("run.speedShort".localized)
                .font(.title3.weight(.medium))
                .foregroundStyle(sheetSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var secondaryStatsCompact: some View {
        HStack(spacing: 12) {
            compactStat(value: elapsedTime, label: "run.timeShort".localized)
            compactStat(value: distanceText, label: "run.distanceShort".localized)
            compactStat(value: "\(territories)", label: "run.zonesShort".localized)
        }
    }

    @ViewBuilder
    private func compactStat(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(sheetPrimaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .contentTransition(.numericText())
                .multilineTextAlignment(.center)

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(sheetSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Expanded Layout

    private var expandedContent: some View {
        VStack(spacing: 16) {
            gpsBadge
                .frame(maxWidth: .infinity, alignment: .trailing)

            // Hero: Distance
            expandedHero(
                value: distanceText,
                label: "run.distanceShort".localized
            )

            // Hero: Duration
            expandedHero(
                value: elapsedTime,
                label: "run.timeShort".localized
            )

            // 2x2 stat cards
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                statCard(
                    value: currentSpeed.formattedCompactSpeedValue,
                    unit: "km/h",
                    label: "run.speedShort".localized,
                    valueColor: speedColor
                )
                statCard(
                    value: avgSpeed.formattedCompactSpeedValue,
                    unit: "km/h",
                    label: "run.avgSpeed".localized,
                    valueColor: sheetPrimaryText
                )
                statCard(
                    value: pace,
                    unit: "/km",
                    label: "run.pace".localized,
                    valueColor: sheetPrimaryText
                )
                statCard(
                    value: "\(territories)",
                    unit: nil,
                    label: "run.zonesShort".localized,
                    valueColor: sheetPrimaryText
                )
            }

            if mode == .boost {
                boostStatusBadge
            }

            Spacer(minLength: 0)

            actionSection
        }
    }

    private func expandedHero(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(sheetPrimaryText)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(sheetSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func statCard(value: String, unit: String?, label: String, valueColor: Color) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                if let unit {
                    Text(unit)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(sheetSecondaryText)
                }
            }

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(sheetSecondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Action Section

    @ViewBuilder
    private var actionSection: some View {
        switch runState {
        case .running:
            Button(action: onPause) {
                Label("run.pause".localized, systemImage: "pause.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SheetActionButtonStyle(fill: .orange, foreground: .white))

        case .paused:
            VStack(spacing: 10) {
                Button(action: onResume) {
                    Label("run.resume".localized, systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                SlideToFinishControl(onComplete: onStop)
            }

        case .finished:
            EmptyView()
        }
    }

    // MARK: - GPS Badge

    private var gpsBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .font(.caption.weight(.bold))
            Text("GPS")
                .font(.caption.weight(.bold))
                .lineLimit(1)
            GPSSignalBars(tint: gpsSignalLost ? .red : .accentColor)
        }
        .foregroundStyle(gpsSignalLost ? Color.red : Color.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background((gpsSignalLost ? Color.red : Color.accentColor).opacity(0.1), in: Capsule())
    }

    // MARK: - Boost Badge

    private var boostStatusBadge: some View {
        Text(boostStatusText)
            .font(.caption.weight(.bold))
            .foregroundStyle(speedColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(speedColor.opacity(0.12), in: Capsule())
            .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var speedColor: Color {
        guard mode == .boost else { return sheetPrimaryText }
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

    private var distanceText: String {
        "\(distance.formattedDecimal(maxFractionDigits: 2, minFractionDigits: 2)) km"
    }

    private var sheetPrimaryText: Color {
        Color.primary
    }

    private var sheetSecondaryText: Color {
        Color.secondary
    }
}

// MARK: - Supporting Views

private struct SheetActionButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.bold())
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill)
            )
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: AppConstants.Animation.quick), value: configuration.isPressed)
    }
}

private struct GPSSignalBars: View {
    let tint: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 2.5) {
            signalBar(height: 6, opacity: 0.4)
            signalBar(height: 9, opacity: 0.6)
            signalBar(height: 12, opacity: 0.8)
            signalBar(height: 15, opacity: 1.0)
        }
        .frame(height: 15)
    }

    private func signalBar(height: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(tint.opacity(opacity))
            .frame(width: 3.5, height: height)
    }
}
