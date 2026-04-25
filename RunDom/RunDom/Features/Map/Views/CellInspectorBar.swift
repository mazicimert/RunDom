import SwiftUI

struct CellInspectorBar: View {
    let inspection: CellInspection
    let ownerDisplayName: String?
    let onDismiss: () -> Void
    let onOpenDetails: () -> Void

    @ObservedObject private var unitPreference = UnitPreference.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3.bold())
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(ownerLabel)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(metaLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if shouldShowDetailsButton {
                Button(action: onOpenDetails) {
                    Text("map.inspector.details".localized)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(uiColor: .tertiarySystemBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("common.dismiss".localized)
        }
        .cardStyle()
    }

    private var iconName: String {
        switch inspection.ownerState {
        case .empty: return "mappin.circle.fill"
        case .mine: return "checkmark.circle.fill"
        case .rival: return "flag.fill"
        }
    }

    private var iconColor: Color {
        switch inspection.ownerState {
        case .empty: return .secondary
        case .mine: return .boostGreen
        case .rival: return .orange
        }
    }

    private var ownerLabel: String {
        switch inspection.ownerState {
        case .empty:
            return "map.inspector.owner.empty".localized
        case .mine:
            return "map.inspector.owner.mine".localized
        case .rival:
            if let name = ownerDisplayName, !name.isEmpty {
                return "map.inspector.owner.rival".localized(with: name)
            }
            return "map.inspector.owner.rival.generic".localized
        }
    }

    private var shouldShowDetailsButton: Bool {
        switch inspection.ownerState {
        case .empty: return false
        case .mine, .rival: return true
        }
    }

    private var metaLabel: String {
        guard let distanceMeters = inspection.distanceMeters else {
            return "map.inspector.meta.noLocation".localized
        }

        let distanceText = (distanceMeters / 1000.0)
            .formattedDistance(useMiles: unitPreference.useMiles)

        guard let seconds = inspection.estimatedSeconds else {
            return "map.inspector.meta.distanceOnly".localized(with: distanceText)
        }

        let minutes = max(1, Int((seconds / 60.0).rounded()))
        let durationText = "map.inspector.duration.minutes".localized(with: minutes)
        return "map.inspector.meta.full".localized(with: distanceText, durationText)
    }
}
