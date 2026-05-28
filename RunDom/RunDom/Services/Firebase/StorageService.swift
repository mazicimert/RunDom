import Foundation
import FirebaseStorage
import UIKit

final class StorageService {
    private let storage = Storage.storage()

    private func profilePhotoRef(userId: String) -> StorageReference {
        storage.reference().child("profilePhotos/\(userId).jpg")
    }

    private func postPhotoRef(userId: String, postId: String, index: Int) -> StorageReference {
        storage.reference().child("postPhotos/\(userId)/\(postId)/\(index).jpg")
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

    // MARK: - Upload Post Photo

    // Re-encoding through UIImage + jpegData strips original EXIF metadata
    // (including GPS), so the user's home/work coordinates can't leak via
    // the uploaded photo.
    func uploadPostPhoto(userId: String, postId: String, index: Int, image: UIImage) async throws -> String {
        let resized = Self.resized(image, maxDimension: AppConstants.PostPhoto.maxDimension)
        guard let data = resized.jpegData(compressionQuality: AppConstants.PostPhoto.jpegQuality) else {
            throw StorageError.compressionFailed
        }

        let ref = postPhotoRef(userId: userId, postId: postId, index: index)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        AppLogger.firebase.info("Post photo uploaded: \(userId)/\(postId)/\(index)")
        return url.absoluteString
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return image }

        let scale = maxDimension / longestSide
        let newSize = CGSize(
            width: floor(size.width * scale),
            height: floor(size.height * scale)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - StorageError

enum StorageError: LocalizedError {
    case compressionFailed

    var errorDescription: String? {
        "error.generic".localized
    }
}
