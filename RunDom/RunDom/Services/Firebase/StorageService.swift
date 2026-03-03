import Foundation
import FirebaseStorage
import UIKit

final class StorageService {
    private let storage = Storage.storage()

    private func profilePhotoRef(userId: String) -> StorageReference {
        storage.reference().child("profilePhotos/\(userId).jpg")
    }

    // MARK: - Upload Profile Photo

    func uploadProfilePhoto(userId: String, image: UIImage) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw StorageError.compressionFailed
        }

        let ref = profilePhotoRef(userId: userId)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        AppLogger.firebase.info("Profile photo uploaded for user: \(userId)")
        return url.absoluteString
    }

    // MARK: - Download Profile Photo URL

    func getProfilePhotoURL(userId: String) async throws -> URL {
        try await profilePhotoRef(userId: userId).downloadURL()
    }

    // MARK: - Delete Profile Photo

    func deleteProfilePhoto(userId: String) async throws {
        try await profilePhotoRef(userId: userId).delete()
        AppLogger.firebase.info("Profile photo deleted for user: \(userId)")
    }
}

// MARK: - StorageError

enum StorageError: LocalizedError {
    case compressionFailed

    var errorDescription: String? {
        "error.generic".localized
    }
}
