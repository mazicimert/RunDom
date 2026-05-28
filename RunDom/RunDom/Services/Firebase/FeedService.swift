import Foundation
import FirebaseFirestore

final class FeedService {

    private let db = Firestore.firestore()

    private func feedCollection(of userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("feed")
    }

    /// Returns the merged feed: follow-graph fan-out + recent public posts
    /// (discovery). Public posts are blended in only on the first page
    /// (`after == nil`) so pagination cursors stay simple. Posts are deduped
    /// by id and sorted by createdAt desc.
    func getFeed(
        userId: String,
        limit: Int = 20,
        after: DocumentSnapshot? = nil
    ) async throws -> (posts: [Post], lastDocument: DocumentSnapshot?) {
        // 1) Follow-graph feed (existing fan-out copies).
        var query: Query = feedCollection(of: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        if let after {
            query = query.start(afterDocument: after)
        }

        let followSnapshot = try await query.getDocuments()
        let followPosts = try followSnapshot.documents
            .compactMap { try $0.data(as: Post.self) }

        // 2) Public discovery — only on first page to keep pagination simple.
        //    Subsequent loadMore() calls only paginate the follow feed.
        var publicPosts: [Post] = []
        if after == nil {
            publicPosts = await fetchRecentPublicPosts(excludingUserId: userId, limit: limit)
        }

        // 3) Merge + dedup by id, sort newest first, cap at page size.
        var seen = Set<String>()
        var merged: [Post] = []
        for post in followPosts + publicPosts {
            if seen.insert(post.id).inserted {
                merged.append(post)
            }
        }
        merged.sort { $0.createdAt > $1.createdAt }
        let trimmed = Array(merged.prefix(limit))

        // 4) Hydrate canonical counts and author display fields.
        // Fan-out copies are written once and never updated when likes/comments
        // change — that would mean N writes per interaction. Instead we hydrate
        // the counts from the canonical post doc with a single batched query
        // so the feed shows fresh numbers without listener churn.
        var hydrated = trimmed
        if !hydrated.isEmpty {
            hydrated = await hydrateCounts(posts: hydrated)
            hydrated = await hydrateAuthors(posts: hydrated)
        }

        // Pagination cursor stays on the follow feed snapshot.
        return (hydrated, followSnapshot.documents.last)
    }

    /// Pulls the most recent N public posts globally, excluding the requester
    /// so they don't see their own post twice. Failure is tolerated — feed
    /// still renders with just the follow graph.
    private func fetchRecentPublicPosts(
        excludingUserId userId: String,
        limit: Int
    ) async -> [Post] {
        do {
            let snapshot = try await db.collection("posts")
                .whereField("visibility", isEqualTo: "public")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            let posts = try snapshot.documents.compactMap { try $0.data(as: Post.self) }
            return posts.filter { $0.authorId != userId }
        } catch {
            AppLogger.firebase.warning("Public posts query failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Refresh the denormalized author fields (displayName / photoURL / color)
    /// from the canonical user docs so newly-uploaded profile photos and name
    /// changes show up in the feed without a fan-out rewrite.
    private func hydrateAuthors(posts: [Post]) async -> [Post] {
        let authorIds = Array(Set(posts.map { $0.authorId }))
        guard !authorIds.isEmpty else { return posts }

        do {
            let usersSnap = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: authorIds)
                .getDocuments()

            var userById: [String: User] = [:]
            for doc in usersSnap.documents {
                if let user = try? doc.data(as: User.self) {
                    userById[user.id] = user
                }
            }

            return posts.map { post in
                var copy = post
                if let user = userById[post.authorId] {
                    copy.authorDisplayName = user.displayName
                    copy.authorPhotoURL = user.photoURL
                    copy.authorColor = user.color
                }
                return copy
            }
        } catch {
            AppLogger.firebase.warning("Feed author hydration failed: \(error.localizedDescription)")
            return posts
        }
    }

    private func hydrateCounts(posts: [Post]) async -> [Post] {
        let postIds = posts.map { $0.id }
        guard !postIds.isEmpty else { return posts }

        do {
            let canonicalSnap = try await db.collection("posts")
                .whereField(FieldPath.documentID(), in: postIds)
                .getDocuments()

            var counts: [String: (likes: Int, comments: Int)] = [:]
            for doc in canonicalSnap.documents {
                let data = doc.data()
                let likes = data["likeCount"] as? Int ?? 0
                let comments = data["commentCount"] as? Int ?? 0
                counts[doc.documentID] = (likes, comments)
            }

            return posts.map { post in
                var copy = post
                if let c = counts[post.id] {
                    copy.likeCount = c.likes
                    copy.commentCount = c.comments
                }
                return copy
            }
        } catch {
            AppLogger.firebase.warning("Feed count hydration failed: \(error.localizedDescription)")
            return posts
        }
    }
}
