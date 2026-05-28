import Foundation
import FirebaseFirestore
import UIKit

final class PostService {

    private let db = Firestore.firestore()
    private let storageService = StorageService()

    private var postsCollection: CollectionReference {
        db.collection("posts")
    }

    // MARK: - Create

    @discardableResult
    func createPost(
        from run: RunSession,
        author: User,
        caption: String?,
        visibility: PostVisibility,
        images: [UIImage] = []
    ) async throws -> Post {
        let id = UUID().uuidString
        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedNote: String? = (trimmedCaption?.isEmpty == false) ? trimmedCaption : nil

        // Upload photos first so we can persist their URLs alongside the post.
        // If any upload fails, no Firestore doc is created — caller surfaces the error.
        var photoURLs: [String] = []
        if !images.isEmpty {
            let capped = Array(images.prefix(AppConstants.PostPhoto.maxCount))
            for (index, image) in capped.enumerated() {
                let url = try await storageService.uploadPostPhoto(
                    userId: author.id,
                    postId: id,
                    index: index,
                    image: image
                )
                photoURLs.append(url)
            }
        }

        // Snapshot the author's current privacy zones from the live cache.
        // Done as a one-shot read (not bound) so each post freezes the masking
        // policy at publish time.
        let zones = await MainActor.run { PrivacyZonesStore.shared.zones }

        let post = Post(
            id: id,
            authorId: author.id,
            authorDisplayName: author.displayName,
            authorPhotoURL: author.photoURL,
            authorColor: author.color,
            runId: run.id,
            createdAt: Date(),
            distance: run.distance,
            duration: run.duration,
            avgSpeed: run.avgSpeed,
            trail: run.trail,
            startDate: run.startDate,
            tags: run.tags,
            note: resolvedNote,
            routePreview: Self.makeRoutePreview(from: run.route, privacyZones: zones),
            shareCardImageURL: nil,
            photoURLs: photoURLs.isEmpty ? nil : photoURLs,
            likeCount: 0,
            commentCount: 0,
            visibility: visibility
        )

        try postsCollection.document(id).setData(from: post)
        AppLogger.firebase.info("Post created: \(id) for run: \(run.id) photos: \(photoURLs.count)")
        return post
    }

    // MARK: - Delete

    func deletePost(_ postId: String) async throws {
        try await postsCollection.document(postId).delete()
        AppLogger.firebase.info("Post deleted: \(postId)")
    }

    // MARK: - Read

    func getPost(id: String) async throws -> Post? {
        let snapshot = try await postsCollection.document(id).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: Post.self)
    }

    func getPosts(
        byUser userId: String,
        limit: Int = 20,
        after: DocumentSnapshot? = nil
    ) async throws -> (posts: [Post], lastDocument: DocumentSnapshot?) {
        var query: Query = postsCollection
            .whereField("authorId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        if let lastDoc = after {
            query = query.start(afterDocument: lastDoc)
        }

        let snapshot = try await query.getDocuments()
        let posts = try snapshot.documents.compactMap { try $0.data(as: Post.self) }
        return (posts, snapshot.documents.last)
    }

    // MARK: - Helpers

    /// Builds the public-facing route preview from a raw run track.
    /// Points falling inside any of the author's privacy zones are stripped
    /// BEFORE downsampling, so the post never leaks home/work coordinates
    /// even when the sampled subset happens to land on a sensitive point.
    private static func makeRoutePreview(
        from route: [RoutePoint],
        privacyZones: [PrivacyZone],
        maxPoints: Int = 40
    ) -> [GeoPoint] {
        guard !route.isEmpty else { return [] }

        // Pass 1: mask. Skipped points leave gaps in the displayed polyline,
        // which is intentional — the visual gap signals "private area" rather
        // than connecting a deceptively straight line across it.
        let filtered: [RoutePoint]
        if privacyZones.isEmpty {
            filtered = route
        } else {
            filtered = route.filter { point in
                !privacyZones.contains(where: {
                    $0.contains(latitude: point.latitude, longitude: point.longitude)
                })
            }
        }

        guard !filtered.isEmpty else { return [] }

        // Pass 2: downsample to at most `maxPoints` for the snapshot.
        if filtered.count <= maxPoints {
            return filtered.map { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) }
        }
        let step = Double(filtered.count) / Double(maxPoints)
        var preview: [GeoPoint] = []
        var index: Double = 0
        while preview.count < maxPoints {
            let i = Int(index)
            if i >= filtered.count { break }
            preview.append(GeoPoint(latitude: filtered[i].latitude, longitude: filtered[i].longitude))
            index += step
        }
        return preview
    }
}
