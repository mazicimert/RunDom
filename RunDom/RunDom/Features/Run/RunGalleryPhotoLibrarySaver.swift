import Photos
import UIKit

enum RunGalleryPhotoLibrarySaver {
    static func save(image: UIImage) async throws {
        let authorization = await requestAddOnlyAuthorizationIfNeeded()

        guard authorization == .authorized || authorization == .limited else {
            throw SaveError.permissionDenied
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? SaveError.saveFailed)
                }
            }
        }
    }

    private static func requestAddOnlyAuthorizationIfNeeded() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch currentStatus {
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    continuation.resume(returning: status)
                }
            }
        default:
            return currentStatus
        }
    }

    enum SaveError: Error, Equatable {
        case permissionDenied
        case saveFailed
    }
}
