import SwiftUI

struct StatCardView: View {
    enum Variant {
        case standard
        case compact
        case hero
    }

    let icon: String
    let value: String
    let label: String
    var iconColor: Color = .accentColor
    var variant: Variant = .standard
    var supportingText: String? = nil
    var detailText: String? = nil
    var detailColor: Color = .secondary

    var body: some View {
        Group {
            switch variant {
            case .standard:
                standardCard
            case .compact:
                compactCard
            case .hero:
                heroCard
            }
        }
    }

    private var standardCard: some View {
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

    private var compactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(iconColor)
            }

            Spacer(minLength: 0)

            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cardBackground,
                            Color.cardBackground.opacity(0.94),
                            iconColor.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(iconColor.opacity(0.18))
                .frame(width: 200, height: 200)
                .blur(radius: 36)
                .offset(x: 56, y: -44)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.subheadline.weight(.bold))
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(iconColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(iconColor.opacity(0.12))
                    )

                    Spacer(minLength: 0)

                    if let detailText {
                        Text(detailText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(detailColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(value)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)

                    if let supportingText {
                        Text(supportingText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 172, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        StatCardView(
            icon: "flame.fill",
            value: "1,250",
            label: "trail.unit".localized,
            iconColor: .orange,
            variant: .hero,
            supportingText: "stats.thisWeek".localized,
            detailText: "+18% vs last week",
            detailColor: .green
        )

        HStack(spacing: 12) {
            StatCardView(
                icon: "figure.run",
                value: "5.2 km",
                label: "run.distance".localized,
                iconColor: .blue,
                variant: .compact
            )
            StatCardView(
                icon: "clock.fill",
                value: "32:15",
                label: "run.duration".localized,
                iconColor: .green,
                variant: .compact
            )
            StatCardView(
                icon: "hexagon.fill",
                value: "12",
                label: "run.territories".localized,
                iconColor: .purple,
                variant: .compact
            )
        }
    }
    .padding()
    .background(Color.surfacePrimary)
}
