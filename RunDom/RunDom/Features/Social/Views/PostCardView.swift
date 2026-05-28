import SwiftUI
import CoreLocation

struct PostCardView: View {
    let post: Post

    @EnvironmentObject private var appState: AppState
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var isProcessingLike = false
    @State private var showDoubleTapHeart = false
    @State private var showReportSheet = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    private let likeService = LikeService()
    private let postService = PostService()

    private var isOwnPost: Bool {
        appState.currentUser?.id == post.authorId
    }

    init(post: Post) {
        self.post = post
        _likeCount = State(initialValue: post.likeCount)
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        post.routePreview.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    private var brandColor: Color {
        Color(hex: post.authorColor) ?? .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            heroMedia
            statsRow
            if let note = post.note, !note.isEmpty {
                noteText(note)
            }
            likeFooter
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
        .task(id: post.id) {
            guard let userId = appState.currentUser?.id else { return }
            do {
                isLiked = try await likeService.isLiked(postId: post.id, userId: userId)
            } catch {
                AppLogger.firebase.warning("isLiked check failed: \(error.localizedDescription)")
            }
        }
        // Sync local state when the parent ViewModel pushes fresh counts
        // (e.g. after the user commented in PostDetailView and popped back).
        .onChange(of: post.likeCount) { _, newValue in
            if !isProcessingLike {
                likeCount = newValue
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportReasonSheet(
                targetType: .post,
                targetId: post.id,
                postId: post.id
            ) {
                HiddenContentStore.shared.hidePost(post.id)
            }
            .environmentObject(appState)
        }
        .confirmationDialog(
            "social.post.delete.confirm.title".localized,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("social.post.delete.confirm.action".localized, role: .destructive) {
                Task { await deletePost() }
            }
            Button("common.cancel".localized, role: .cancel) {}
        } message: {
            Text("social.post.delete.confirm.message".localized)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            NavigationLink {
                UserProfileView(userId: post.authorId)
                    .environmentObject(appState)
            } label: {
                HStack(spacing: 12) {
                    AvatarView(
                        photoURL: post.authorPhotoURL,
                        userColor: post.authorColor,
                        size: 44
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.authorDisplayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(post.createdAt.relativeFormatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            actionMenu
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var actionMenu: some View {
        Menu {
            if isOwnPost {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("social.post.delete".localized, systemImage: "trash")
                }
            } else {
                Button {
                    showReportSheet = true
                } label: {
                    Label("social.post.report".localized, systemImage: "flag")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .disabled(isDeleting)
    }

    private var photoURLs: [URL] {
        (post.photoURLs ?? []).compactMap(URL.init(string:))
    }

    @ViewBuilder
    private var heroMedia: some View {
        ZStack {
            if !photoURLs.isEmpty {
                PostPhotoCarousel(urls: photoURLs)
            } else if routeCoordinates.count > 1 {
                RoutePreviewMap(
                    coordinates: routeCoordinates,
                    strokeColor: UIColor(brandColor)
                )
            } else {
                LinearGradient(
                    colors: [
                        brandColor.opacity(0.55),
                        brandColor.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "figure.run")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.85))
            }

            if showDoubleTapHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 8)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .frame(height: 220)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            Task { await handleDoubleTap() }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            metricPill(
                icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                value: post.distance.formattedDistanceFromMeters,
                tint: .green
            )
            metricPill(
                icon: "clock.fill",
                value: Self.formatDuration(post.duration),
                tint: .blue
            )
            metricPill(
                icon: "flame.fill",
                value: post.trail.formattedTrail,
                tint: .orange
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func metricPill(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }

    private var likeFooter: some View {
        HStack(spacing: 18) {
            Button {
                Task { await toggleLike() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(isLiked ? Color.red : .secondary)
                        .symbolEffect(.bounce, value: isLiked)
                    Text("\(likeCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .buttonStyle(.plain)
            .disabled(isProcessingLike)

            NavigationLink {
                PostDetailView(postId: post.id)
                    .environmentObject(appState)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("\(post.commentCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private func noteText(_ note: String) -> some View {
        Text(note)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
    }

    @MainActor
    private func toggleLike() async {
        guard let userId = appState.currentUser?.id, !isProcessingLike else { return }
        isProcessingLike = true

        let wasLiked = isLiked
        isLiked.toggle()
        likeCount = max(0, likeCount + (wasLiked ? -1 : 1))
        Haptics.impact(.light)

        do {
            if wasLiked {
                try await likeService.unlike(postId: post.id, userId: userId)
            } else {
                try await likeService.like(postId: post.id, userId: userId)
            }
        } catch {
            AppLogger.firebase.error("Like toggle failed: \(error.localizedDescription)")
            isLiked = wasLiked
            likeCount = max(0, likeCount + (wasLiked ? 1 : -1))
        }

        isProcessingLike = false
    }

    @MainActor
    private func deletePost() async {
        guard isOwnPost, !isDeleting else { return }
        isDeleting = true
        do {
            try await postService.deletePost(post.id)
            // Hide locally so the row disappears from the feed before the
            // Cloud Function fan-out delete propagates to followers' feeds.
            HiddenContentStore.shared.hidePost(post.id)
            Haptics.notification(.success)
        } catch {
            AppLogger.firebase.error("Post delete failed: \(error.localizedDescription)")
            Haptics.notification(.error)
        }
        isDeleting = false
    }

    @MainActor
    private func handleDoubleTap() async {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
            showDoubleTapHeart = true
        }
        Haptics.impact(.medium)

        if !isLiked, !isProcessingLike {
            await toggleLike()
        }

        try? await Task.sleep(nanoseconds: 700_000_000)
        withAnimation(.easeOut(duration: 0.25)) {
            showDoubleTapHeart = false
        }
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Photo Carousel

struct PostPhotoCarousel: View {
    let urls: [URL]
    @State private var selection: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    CachedImageView(url: url, contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if urls.count > 1 {
                pageIndicator
                    .padding(.bottom, 10)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<urls.count, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(index == selection ? 0.95 : 0.45))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color.black.opacity(0.35))
        )
    }
}
