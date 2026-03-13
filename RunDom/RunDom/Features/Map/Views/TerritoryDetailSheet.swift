import SwiftUI

struct TerritoryDetailSheet: View {
    @StateObject private var viewModel: TerritoryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(territory: Territory, currentUserId: String?) {
        _viewModel = StateObject(wrappedValue: TerritoryDetailViewModel(
            territory: territory,
            currentUserId: currentUserId
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Owner Color Badge
                ownerBadge

                // Defense Level
                defenseSection

                // Stats
                statsSection

                Spacer()
            }
            .padding(.top, 8)
            .screenPadding()
            .navigationTitle("map.territoryDetail".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done".localized) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Owner Badge

    private var ownerBadge: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(viewModel.ownerColor)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: viewModel.isCurrentUser ? "crown.fill" : "person.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("map.owner".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.ownerName)
                    .font(.headline)
            }

            Spacer()

            if viewModel.territory.isDecaying {
                Label("map.decaying".localized, systemImage: "arrow.down.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
        }
        .cardStyle()
    }

    // MARK: - Defense Section

    private var defenseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("map.defense".localized)
                .font(.subheadline.bold())

            HStack {
                ProgressView(value: viewModel.defensePercentage)
                    .tint(viewModel.defenseColor)

                Text(String(format: "%.0f", viewModel.territory.decayedDefenseLevel))
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(viewModel.defenseColor)
            }

            if viewModel.territory.isDecaying {
                Text("map.defenseDecaying".localized)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .cardStyle()
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCardView(
                icon: "ruler",
                value: viewModel.totalDistanceText,
                label: "run.distance".localized,
                iconColor: .blue
            )
            .frame(maxWidth: .infinity, minHeight: 160)

            StatCardView(
                icon: "clock.fill",
                value: viewModel.lastActiveText,
                label: "map.lastActive".localized,
                iconColor: .green
            )
            .frame(maxWidth: .infinity, minHeight: 160)
        }
    }
}
