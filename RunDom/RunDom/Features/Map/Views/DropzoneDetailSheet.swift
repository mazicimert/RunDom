import SwiftUI

struct DropzoneDetailSheet: View {
    let dropzone: Dropzone
    let currentUserId: String?
    let onClaim: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Dropzone Icon
                dropzoneHeader

                // Status
                statusSection

                // Reward
                rewardSection

                // Claim Button
                if let userId = currentUserId, dropzone.canClaim(userId: userId) {
                    claimButton
                }

                Spacer()
            }
            .padding(.top, 8)
            .screenPadding()
            .navigationTitle("dropzone.active".localized)
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

    // MARK: - Header

    private var dropzoneHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.yellow.gradient)
                    .frame(width: 72, height: 72)

                Image(systemName: "bolt.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            }

            Text(dropzone.isActive ? "dropzone.active".localized : "dropzone.hint".localized(with: timeUntilActive))
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("dropzone.spotsLeft".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(spotsRemaining)/\(AppConstants.Game.dropzoneMaxClaimants)")
                    .font(.subheadline.bold().monospacedDigit())
            }

            HStack {
                Text("dropzone.expiresIn".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(timeUntilExpiration)
                    .font(.subheadline.bold().monospacedDigit())
            }

            if let userId = currentUserId, dropzone.claimedBy.contains(userId) {
                Label("dropzone.claimed".localized, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            }
        }
        .cardStyle()
    }

    // MARK: - Reward

    private var rewardSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.circle.fill")
                .font(.title)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("dropzone.reward".localized)
                    .font(.subheadline.bold())
                Text("dropzone.rewardDesc".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .cardStyle()
    }

    // MARK: - Claim Button

    private var claimButton: some View {
        Button {
            onClaim()
            dismiss()
        } label: {
            Label("dropzone.claim".localized, systemImage: "bolt.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    // MARK: - Computed

    private var spotsRemaining: Int {
        max(AppConstants.Game.dropzoneMaxClaimants - dropzone.claimedBy.count, 0)
    }

    private var timeUntilActive: String {
        guard !dropzone.isActive else { return "" }
        let interval = dropzone.activationDate.timeIntervalSince(Date())
        guard interval > 0 else { return "" }
        return interval.formattedDuration
    }

    private var timeUntilExpiration: String {
        let interval = dropzone.expirationDate.timeIntervalSince(Date())
        guard interval > 0 else { return "—" }
        return interval.formattedDuration
    }
}
