import SwiftUI

struct RunStatsOverlayView: View {
    let distance: Double // km
    let elapsedTime: String
    let pace: String
    let territories: Int
    let uniqueZones: Int

    var body: some View {
        HStack(spacing: 0) {
            statItem(value: String(format: "%.2f", distance), label: "km")
            divider
            statItem(value: elapsedTime, label: "run.time".localized)
            divider
            statItem(value: pace, label: "run.pace".localized)
            divider
            statItem(value: "\(territories)", label: "run.zones".localized)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
    }

    @ViewBuilder
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Divider()
            .frame(height: 30)
    }
}
