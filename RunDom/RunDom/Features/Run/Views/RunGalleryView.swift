import SwiftUI
import FirebaseFirestore

struct RunGalleryView: View {
    let session: RunSession

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var snapshotImage: UIImage?
    @State private var shareItems: [Any] = []
    @State private var isShareSheetPresented = false
    @State private var isRendering = false
    @State private var isSaving = false
    @State private var isLoadingSnapshot = true
    @State private var galleryAlert: GalleryAlert?
    @State private var isPermissionAlertPresented = false
    @State private var selectedTemplate: PostShareTemplate = .hero
    @State private var didSaveCurrentPreview = false

    private let previewRenderSize = CGSize(width: 1080, height: 1920)

    private var canExport: Bool {
        snapshotImage != nil && !isLoadingSnapshot && !isRendering && !isSaving
    }

    private var canSavePreview: Bool {
        canExport && !didSaveCurrentPreview
    }

    var body: some View {
        NavigationStack {
            ZStack {
                galleryBackground
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    previewSection
                    controlsSection
                    Spacer(minLength: 0)
                    actionBar
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .navigationTitle("run.gallery".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.08, green: 0.06, blue: 0.06), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $isShareSheetPresented) {
                ShareSheet(items: shareItems)
            }
            .alert(item: $galleryAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("common.ok".localized))
                )
            }
            .alert("run.gallery.permissionDenied.title".localized, isPresented: $isPermissionAlertPresented) {
                Button("common.settings".localized) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("common.cancel".localized, role: .cancel) {}
            } message: {
                Text("run.gallery.permissionDenied".localized)
            }
            .task {
                await loadSnapshot()
            }
            .onChange(of: selectedTemplate) { _ in
                didSaveCurrentPreview = false
            }
        }
    }

    private var galleryBackground: some View {
        ZStack {
            Color(red: 0.08, green: 0.06, blue: 0.06)

            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.08, blue: 0.08),
                    Color(red: 0.08, green: 0.06, blue: 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color.territoryBlue.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: -120, y: -260)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("run.gallery.preview".localized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.05))

                if let snapshotImage {
                    scaledGalleryPreview(snapshotImage: snapshotImage)
                    .transition(.opacity)
                } else if isLoadingSnapshot {
                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(.white)
                        Text("run.gallery.loadingMap".localized)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "map")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white.opacity(0.72))
                        Text("run.gallery.mapFailed".localized)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
            }
            .aspectRatio(previewRenderSize.width / previewRenderSize.height, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private func scaledGalleryPreview(snapshotImage: UIImage) -> some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / previewRenderSize.width,
                proxy.size.height / previewRenderSize.height
            )

            PostShareCardView(
                post: galleryPost,
                photoImage: snapshotImage,
                template: selectedTemplate
            )
            .frame(width: previewRenderSize.width, height: previewRenderSize.height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .allowsHitTesting(false)
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("social.externalShare.template".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            HStack(spacing: 8) {
                ForEach(PostShareTemplate.allCases) { template in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            selectedTemplate = template
                        }
                    } label: {
                        Text(template.localizedName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(selectedTemplate == template ? Color.black : .white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(selectedTemplate == template ? Color.white : Color.white.opacity(0.04))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var actionBar: some View {
        HStack(spacing: 14) {
            Button(action: saveToPhotoLibrary) {
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView()
                            .tint(didSaveCurrentPreview ? .white : .black)
                    } else if didSaveCurrentPreview {
                        Image(systemName: "checkmark.circle.fill")
                    } else {
                        Image(systemName: "arrow.down.to.line")
                    }
                    Text(didSaveCurrentPreview ? "run.gallery.savedButton".localized : "common.save".localized)
                }
                .font(.title3.weight(.bold))
                .foregroundStyle(didSaveCurrentPreview ? .white : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    didSaveCurrentPreview ? Color.accentColor : Color.white,
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSavePreview)
            .opacity(canSavePreview || didSaveCurrentPreview ? 1 : 0.6)

            Button(action: shareImage) {
                HStack(spacing: 10) {
                    if isRendering {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text("common.share".localized)
                }
                .font(.title3.weight(.bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canExport)
            .opacity(canExport ? 1 : 0.6)
        }
    }

    private func loadSnapshot() async {
        isLoadingSnapshot = true

        do {
            let image = try await RunGalleryMapSnapshotter.snapshot(for: session, size: previewRenderSize)
            snapshotImage = image
            didSaveCurrentPreview = false
        } catch {
            AppLogger.run.error("Gallery snapshot failed: \(error.localizedDescription)")
            galleryAlert = GalleryAlert(
                title: "common.error".localized,
                message: "run.gallery.mapFailed".localized
            )
        }

        isLoadingSnapshot = false
    }

    private func shareImage() {
        guard canExport else { return }
        isRendering = true

        guard let image = renderedPreviewImage() else {
            isRendering = false
            galleryAlert = GalleryAlert(
                title: "common.error".localized,
                message: "run.summary.shareFailed".localized
            )
            return
        }

        shareItems = [image]
        isRendering = false
        isShareSheetPresented = true
    }

    private func saveToPhotoLibrary() {
        guard canSavePreview else { return }

        isSaving = true
        didSaveCurrentPreview = false

        guard let image = renderedPreviewImage() else {
            isSaving = false
            galleryAlert = GalleryAlert(
                title: "common.error".localized,
                message: "run.gallery.saveFailed".localized
            )
            return
        }

        Task {
            do {
                try await RunGalleryPhotoLibrarySaver.save(image: image)
                await MainActor.run {
                    isSaving = false
                    didSaveCurrentPreview = true
                    galleryAlert = GalleryAlert(
                        title: "common.save".localized,
                        message: "run.gallery.saved".localized
                    )
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    if let saveError = error as? RunGalleryPhotoLibrarySaver.SaveError,
                       saveError == .permissionDenied {
                        isPermissionAlertPresented = true
                    } else {
                        galleryAlert = GalleryAlert(
                            title: "common.error".localized,
                            message: "run.gallery.saveFailed".localized
                        )
                    }
                }
            }
        }
    }

    private func renderedPreviewImage() -> UIImage? {
        guard let snapshotImage else { return nil }

        let preview = PostShareCardView(
            post: galleryPost,
            photoImage: snapshotImage,
            template: selectedTemplate
        )
        .frame(width: previewRenderSize.width, height: previewRenderSize.height)
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: preview)
        renderer.proposedSize = ProposedViewSize(previewRenderSize)
        renderer.scale = 3
        return renderer.uiImage
    }

    private var galleryPost: Post {
        Post(
            id: session.id,
            authorId: session.userId,
            authorDisplayName: "Runpire",
            authorPhotoURL: nil,
            authorColor: appState.currentUser?.color ?? "#4ECDC4",
            runId: session.id,
            createdAt: Date(),
            distance: session.distance,
            duration: session.duration,
            avgSpeed: session.avgSpeed,
            trail: session.trail,
            startDate: session.startDate,
            tags: session.tags,
            note: session.note,
            routePreview: session.route.map { point in
                GeoPoint(latitude: point.latitude, longitude: point.longitude)
            },
            shareCardImageURL: nil,
            photoURLs: nil
        )
    }
}

private struct GalleryAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    RunGalleryView(session: RunSession(
        id: "gallery-preview",
        userId: "preview",
        mode: .normal,
        startDate: Date().addingTimeInterval(-600),
        endDate: Date(),
        distance: 810,
        avgSpeed: 8.4,
        maxSpeed: 11.2,
        trail: 124,
        territoriesCaptured: 3,
        uniqueZonesVisited: 4,
        totalZonesVisited: 5,
        route: [
            RoutePoint(latitude: 41.021, longitude: 28.974, timestamp: Date(), speed: 2.1, altitude: 20),
            RoutePoint(latitude: 41.024, longitude: 28.981, timestamp: Date(), speed: 2.3, altitude: 18),
            RoutePoint(latitude: 41.028, longitude: 28.989, timestamp: Date(), speed: 2.4, altitude: 22)
        ]
    ))
    .environmentObject(AppState())
}
