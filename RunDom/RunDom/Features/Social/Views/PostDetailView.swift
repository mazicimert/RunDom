import SwiftUI
import CoreLocation

struct PostDetailView: View {
    let postId: String

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: PostDetailViewModel
    @State private var newCommentText: String = ""
    @State private var isLiked = false
    @State private var localLikeCount: Int = 0
    @State private var isProcessingLike = false
    @State private var showDoubleTapHeart = false
    @State private var showReportSheet = false
    @State private var reportCommentTarget: Comment?
    @State private var showDeleteConfirm = false
    @State private var showShareComposer = false
    @FocusState private var isInputFocused: Bool

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var hiddenStore = HiddenContentStore.shared
    @ObservedObject private var blockedStore = BlockedUsersStore.shared
    private let likeService = LikeService()
    private let postService = PostService()

    private var visibleComments: [Comment] {
        viewModel.comments.filter { comment in
            !hiddenStore.isCommentHidden(comment.id)
            && !blockedStore.hasBlockRelationship(with: comment.authorId)
        }
    }

    private var isOwnPost: Bool {
        appState.currentUser?.id == viewModel.post?.authorId
    }

    init(postId: String) {
        self.postId = postId
        _viewModel = StateObject(wrappedValue: PostDetailViewModel(postId: postId))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .padding(.vertical, 16)
            }
            .background(Color.surfacePrimary)

            Divider().opacity(0.4)
            commentInputBar
        }
        .background(Color.surfacePrimary.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.post != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            showShareComposer = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .accessibilityLabel("common.share".localized)
                        postActionMenu
                    }
                }
            }
        }
        .task(id: postId) {
            await viewModel.load()
            if let post = viewModel.post {
                localLikeCount = post.likeCount
                if let userId = appState.currentUser?.id {
                    isLiked = (try? await likeService.isLiked(postId: postId, userId: userId)) ?? false
                }
            }
        }
        .refreshable {
            await viewModel.load()
            if let post = viewModel.post {
                localLikeCount = post.likeCount
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportReasonSheet(
                targetType: .post,
                targetId: postId,
                postId: postId
            ) {
                HiddenContentStore.shared.hidePost(postId)
                dismiss()
            }
            .environmentObject(appState)
        }
        .sheet(item: $reportCommentTarget) { comment in
            ReportReasonSheet(
                targetType: .comment,
                targetId: comment.id,
                postId: postId
            ) {
                HiddenContentStore.shared.hideComment(comment.id)
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
        .sheet(isPresented: $showShareComposer) {
            if let post = viewModel.post {
                PostShareComposerView(post: post)
            }
        }
    }

    private var postActionMenu: some View {
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
        }
    }

    @MainActor
    private func deletePost() async {
        guard isOwnPost else { return }
        do {
            try await postService.deletePost(postId)
            HiddenContentStore.shared.hidePost(postId)
            Haptics.notification(.success)
            dismiss()
        } catch {
            AppLogger.firebase.error("Post delete failed: \(error.localizedDescription)")
            Haptics.notification(.error)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let post = viewModel.post {
            VStack(alignment: .leading, spacing: 20) {
                postCard(post)
                commentsSection
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)
        } else if viewModel.isLoading {
            ProgressView()
                .padding(.top, 80)
                .frame(maxWidth: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            ErrorBannerView(
                message: errorMessage,
                onDismiss: { viewModel.errorMessage = nil },
                onRetry: { Task { await viewModel.load() } }
            )
            .padding(.horizontal, AppConstants.UI.screenPadding)
        }
    }

    private func postCard(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            postHeader(post)
            heroMedia(post)
            metricsRow(post)
            if hasPhotos(post), post.routePreview.count > 1 {
                secondaryRouteMap(post)
            }
            if let note = post.note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
            likeRow
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.cardBackground)
        )
    }

    private func hasPhotos(_ post: Post) -> Bool {
        !(post.photoURLs ?? []).isEmpty
    }

    private func photoURLs(_ post: Post) -> [URL] {
        (post.photoURLs ?? []).compactMap(URL.init(string:))
    }

    @ViewBuilder
    private func heroMedia(_ post: Post) -> some View {
        let urls = photoURLs(post)
        if !urls.isEmpty {
            ZStack {
                PostPhotoCarousel(urls: urls)
                if showDoubleTapHeart {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 110))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 10)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.3).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .frame(height: 320)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                Task { await handleDoubleTap() }
            }
        } else {
            routePreview(post)
        }
    }

    @ViewBuilder
    private func secondaryRouteMap(_ post: Post) -> some View {
        let coordinates = post.routePreview.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let brand = Color(hex: post.authorColor) ?? .accentColor

        RoutePreviewMap(coordinates: coordinates, strokeColor: UIColor(brand))
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
    }

    private func postHeader(_ post: Post) -> some View {
        // Prefer the canonical author so the hero reflects the user's CURRENT
        // photo / name / color, not the snapshot taken at post-creation time.
        let displayName = viewModel.author?.displayName ?? post.authorDisplayName
        let displayPhotoURL = viewModel.author?.photoURL ?? post.authorPhotoURL
        let displayColor = viewModel.author?.color ?? post.authorColor

        return HStack(spacing: 12) {
            NavigationLink {
                UserProfileView(userId: post.authorId)
                    .environmentObject(appState)
            } label: {
                HStack(spacing: 12) {
                    AvatarView(
                        photoURL: displayPhotoURL,
                        userColor: displayColor,
                        size: 44
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
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
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func routePreview(_ post: Post) -> some View {
        let coordinates = post.routePreview.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let brand = Color(hex: post.authorColor) ?? .accentColor

        ZStack {
            if coordinates.count > 1 {
                RoutePreviewMap(coordinates: coordinates, strokeColor: UIColor(brand))
            } else {
                LinearGradient(
                    colors: [brand.opacity(0.55), brand.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "figure.run")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.85))
            }

            if showDoubleTapHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 110))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 10)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .frame(height: 240)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            Task { await handleDoubleTap() }
        }
    }

    private func metricsRow(_ post: Post) -> some View {
        HStack(spacing: 6) {
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
            if post.avgSpeed > 0 {
                metricPill(
                    icon: "stopwatch.fill",
                    value: "\(post.avgSpeed.formattedPace) \(UnitPreference.shared.paceUnitLabel)",
                    tint: .purple
                )
            }
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
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .layoutPriority(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.12)))
    }

    private var likeRow: some View {
        HStack(spacing: 18) {
            Button {
                Task { await toggleLike() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(isLiked ? Color.red : .secondary)
                        .symbolEffect(.bounce, value: isLiked)
                    Text("\(localLikeCount)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .buttonStyle(.plain)
            .disabled(isProcessingLike)

            HStack(spacing: 6) {
                Image(systemName: "bubble.left")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("\(viewModel.post?.commentCount ?? 0)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    // MARK: - Comments

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("social.comments.title".localized)
                .font(.headline)

            if visibleComments.isEmpty {
                Text("social.comments.empty".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(visibleComments) { comment in
                        commentRow(comment)
                    }
                }
            }
        }
    }

    private func commentRow(_ comment: Comment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(
                photoURL: comment.authorPhotoURL,
                userColor: "#4ECDC4",
                size: 36
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.authorDisplayName)
                        .font(.caption.weight(.semibold))
                    Text(comment.createdAt.relativeFormatted())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(comment.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cardBackground)
        )
        .contextMenu {
            if viewModel.canDelete(comment, currentUserId: appState.currentUser?.id) {
                Button(role: .destructive) {
                    Task { await viewModel.deleteComment(comment) }
                } label: {
                    Label("social.comments.delete".localized, systemImage: "trash")
                }
            } else if appState.currentUser?.id != comment.authorId {
                Button {
                    reportCommentTarget = comment
                } label: {
                    Label("social.comments.report".localized, systemImage: "flag")
                }
            }
        }
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        HStack(spacing: 10) {
            TextField(
                "social.comments.placeholder".localized,
                text: $newCommentText,
                axis: .vertical
            )
            .lineLimit(1...4)
            .focused($isInputFocused)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.cardBackground)
            )

            Button {
                sendComment()
            } label: {
                if viewModel.isPostingComment {
                    ProgressView()
                        .frame(width: 38, height: 38)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(canSend ? Color.accentColor : .secondary)
                }
            }
            .disabled(!canSend || viewModel.isPostingComment)
        }
        .padding(.horizontal, AppConstants.UI.screenPadding)
        .padding(.vertical, 10)
        .background(Color.surfacePrimary)
    }

    private var canSend: Bool {
        !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendComment() {
        guard let user = appState.currentUser, canSend else { return }
        let text = newCommentText
        Task {
            await viewModel.addComment(text: text, author: user)
            if viewModel.errorMessage == nil {
                newCommentText = ""
                isInputFocused = false
                Haptics.notification(.success)
            }
        }
    }

    // MARK: - Like

    @MainActor
    private func toggleLike() async {
        guard let userId = appState.currentUser?.id, !isProcessingLike else { return }
        isProcessingLike = true

        let wasLiked = isLiked
        isLiked.toggle()
        let delta = wasLiked ? -1 : 1
        localLikeCount = max(0, localLikeCount + delta)
        Haptics.impact(.light)

        do {
            if wasLiked {
                try await likeService.unlike(postId: postId, userId: userId)
            } else {
                try await likeService.like(postId: postId, userId: userId)
            }
            viewModel.applyLikeDelta(delta)
        } catch {
            AppLogger.firebase.error("Like toggle failed: \(error.localizedDescription)")
            isLiked = wasLiked
            localLikeCount = max(0, localLikeCount - delta)
        }

        isProcessingLike = false
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
