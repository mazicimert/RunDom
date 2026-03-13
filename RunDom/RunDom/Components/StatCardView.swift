import SwiftUI

struct StatCardView: View {
    let icon: String
    let value: String
    let label: String
    var iconColor: Color = .accentColor

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)

            Text(value)
                .font(.title2.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

#Preview {
    HStack(spacing: 12) {
        StatCardView(
            icon: "flame.fill",
            value: "1,250",
            label: "trail.unit".localized,
            iconColor: .orange
        )
        StatCardView(
            icon: "figure.run",
            value: "5.2 km",
            label: "run.distance".localized,
            iconColor: .blue
        )
        StatCardView(
            icon: "clock.fill",
            value: "32:15",
            label: "run.duration".localized,
            iconColor: .green
        )
    }
    .padding()
}
