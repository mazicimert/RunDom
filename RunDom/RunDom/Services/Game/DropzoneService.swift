import Foundation
import CoreLocation

/// Manages dropzone proximity checks, claiming, and reward activation.
final class DropzoneService {

    // MARK: - Services

    private let firestoreService: FirestoreService
    private let h3Service: H3GridService

    init(
        firestoreService: FirestoreService = FirestoreService(),
        h3Service: H3GridService = .shared
    ) {
        self.firestoreService = firestoreService
        self.h3Service = h3Service
    }

    // MARK: - Claim Result

    struct ClaimResult {
        let success: Bool
        let dropzoneId: String
        let rewardMultiplier: Double
        let rewardDurationDays: Int
        let expiryDate: Date?
    }

    // MARK: - Proximity Check

    /// Returns the closest active dropzone within claiming range, if any.
    func nearestClaimableDropzone(
        location: CLLocationCoordinate2D,
        userId: String,
        dropzones: [Dropzone]
    ) -> Dropzone? {
        let userH3 = h3Service.h3Index(for: location)

        return dropzones
            .filter { $0.canClaim(userId: userId) }
            .first { dropzone in
                let dropzoneH3 = dropzone.h3Index
                // Claimable if user is in the same cell or a neighboring cell
                if dropzoneH3 == userH3 { return true }
                let neighbors = h3Service.neighbors(forIndex: dropzoneH3)
                return neighbors.contains(userH3)
            }
    }

    /// Checks if a user is close enough to a specific dropzone.
    func isInRange(
        userLocation: CLLocationCoordinate2D,
        dropzone: Dropzone
    ) -> Bool {
        let userH3 = h3Service.h3Index(for: userLocation)
        let dropzoneH3 = dropzone.h3Index

        if dropzoneH3 == userH3 { return true }
        let neighbors = h3Service.neighbors(forIndex: dropzoneH3)
        return neighbors.contains(userH3)
    }

    // MARK: - Claim

    /// Claims a dropzone for a user and activates the reward.
    func claimDropzone(dropzoneId: String, userId: String) async throws -> ClaimResult {
        do {
            try await firestoreService.claimDropzone(dropzoneId: dropzoneId, userId: userId)

            let expiryDate = Calendar.current.date(
                byAdding: .day,
                value: AppConstants.Game.dropzoneRewardDays,
                to: Date()
            )

            // Update user's dropzone multiplier expiry
            if var user = try await firestoreService.getUser(id: userId) {
                user.dropzoneMultiplierExpiry = expiryDate
                try await firestoreService.updateUser(user)
            }

            AppLogger.game.info("Dropzone \(dropzoneId) claimed by \(userId), reward until \(expiryDate?.description ?? "nil")")

            return ClaimResult(
                success: true,
                dropzoneId: dropzoneId,
                rewardMultiplier: AppConstants.Game.dropzoneRewardMultiplier,
                rewardDurationDays: AppConstants.Game.dropzoneRewardDays,
                expiryDate: expiryDate
            )
        } catch {
            AppLogger.game.error("Failed to claim dropzone \(dropzoneId): \(error.localizedDescription)")
            return ClaimResult(
                success: false,
                dropzoneId: dropzoneId,
                rewardMultiplier: 1.0,
                rewardDurationDays: 0,
                expiryDate: nil
            )
        }
    }

    // MARK: - Active Dropzones

    /// Returns all currently active or hint-visible dropzones.
    func getActiveDropzones() async throws -> [Dropzone] {
        let dropzones = try await firestoreService.getActiveDropzones()
        return dropzones.filter { $0.isActive || $0.isHintVisible }
    }

    // MARK: - Reward Status

    /// Checks if a user currently has an active dropzone reward.
    func hasActiveReward(user: User) -> Bool {
        user.hasActiveDropzoneBoost
    }

    /// Returns the remaining time for the dropzone reward, or nil if no active reward.
    func rewardTimeRemaining(user: User) -> TimeInterval? {
        guard let expiry = user.dropzoneMultiplierExpiry, expiry > Date() else {
            return nil
        }
        return expiry.timeIntervalSince(Date())
    }
}
