import SwiftUI

struct RunGalleryView: View {
    let session: RunSession

    @Environment(\.dismiss) private var dismiss
    @Namespace private var overlayToggleNamespace

    @State private var snapshotImage: UIImage?
    @State private var shareItems: [Any] = []
    @State private var isShareSheetPresented = false
    @State private var isRendering = false
    @State private var isSaving = false
    @State private var isLoadingSnapshot = true
    @State private var galleryAlert: GalleryAlert?
    @State private var showsOverlays = true
    @State private var didSaveCurrentPreview = false

    private let previewRenderSize = CGSize(width: 1080, height: 1350)

    private var summaryViewModel: PostRunViewModel {
        PostRunViewModel(session: session)
    }

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
            .task {
                await loadSnapshot()
            }
            .onChange(of: showsOverlays) { _ in
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
                    RunGalleryPreviewCard(
                        snapshotImage: snapshotImage,
                        session: session,
                        trailText: summaryViewModel.trailText,
                        showOverlays: showsOverlays
                    )
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

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("run.gallery.overlays".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            HStack(spacing: 10) {
                overlayToggleButton(
                    title: "run.gallery.showOverlays".localized,
                    isSelected: showsOverlays
                ) {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                        showsOverlays = true
                    }
                }

                overlayToggleButton(
                    title: "run.gallery.hideOverlays".localized,
                    isSelected: !showsOverlays
                ) {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                        showsOverlays = false
                    }
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

    private func overlayToggleButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? Color.black : .white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                            .matchedGeometryEffect(id: "overlay-toggle", in: overlayToggleNamespace)
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    }
                }
        }
        .buttonStyle(.plain)
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
                    let message: String
                    if let error = error as? RunGalleryPhotoLibrarySaver.SaveError,
                       error == .permissionDenied {
                        message = "run.gallery.permissionDenied".localized
                    } else {
                        message = "run.gallery.saveFailed".localized
                    }
                    galleryAlert = GalleryAlert(
                        title: "common.error".localized,
                        message: message
                    )
                }
            }
        }
    }

    private func renderedPreviewImage() -> UIImage? {
        guard let snapshotImage else { return nil }

        let preview = RunGalleryPreviewCard(
            snapshotImage: snapshotImage,
            session: session,
            trailText: summaryViewModel.trailText,
            showOverlays: showsOverlays
        )
        .frame(width: previewRenderSize.width, height: previewRenderSize.height)

        let renderer = ImageRenderer(content: preview)
        renderer.proposedSize = ProposedViewSize(previewRenderSize)
        renderer.scale = 1
        return renderer.uiImage
    }
}

private struct RunGalleryPreviewCard: View {
    let snapshotImage: UIImage
    let session: RunSession
    let trailText: String
    let showOverlays: Bool

    private let accentColor = Color.accentColor

    private var metrics: [(value: String, title: String)] {
        [
            (session.distance.formattedDistanceFromMeters, "run.distance".localized),
            (session.duration.formattedDuration, "run.duration".localized),
            (session.avgSpeed.formattedSpeed, "run.avgSpeed".localized)
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let horizontalPadding = max(size.width * 0.055, 20)
            let topPadding = max(size.height * 0.034, 18)
            let bottomPadding = max(size.height * 0.05, 26)
            let brandFontSize = min(size.width * 0.16, 62)
            let trailFontSize = min(size.width * 0.19, 72)
            let trailLabelFontSize = min(size.width * 0.05, 19)
            let metricValueFontSize = min(size.width * 0.085, 32)
            let metricLabelFontSize = min(size.width * 0.042, 17)

            ZStack(alignment: .top) {
                Image(uiImage: snapshotImage)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.12),
                                Color.clear,
                                Color.black.opacity(showOverlays ? 0.44 : 0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                overlayContent(
                    size: size,
                    horizontalPadding: horizontalPadding,
                    topPadding: topPadding,
                    bottomPadding: bottomPadding,
                    brandFontSize: brandFontSize,
                    trailFontSize: trailFontSize,
                    trailLabelFontSize: trailLabelFontSize,
                    metricValueFontSize: metricValueFontSize,
                    metricLabelFontSize: metricLabelFontSize
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    @ViewBuilder
    private func overlayContent(
        size: CGSize,
        horizontalPadding: CGFloat,
        topPadding: CGFloat,
        bottomPadding: CGFloat,
        brandFontSize: CGFloat,
        trailFontSize: CGFloat,
        trailLabelFontSize: CGFloat,
        metricValueFontSize: CGFloat,
        metricLabelFontSize: CGFloat
    ) -> some View {
        if showOverlays {
            VStack(spacing: 0) {
                Text("RUNPIRE")
                    .font(.system(size: brandFontSize, weight: .black, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, topPadding)
                    .padding(.horizontal, horizontalPadding)
                    .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))

                Spacer()

                VStack(spacing: max(size.height * 0.014, 10)) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(trailText)
                            .font(.system(size: trailFontSize, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)

                        Text("run.trailEarned".localized.uppercased())
                            .font(.system(size: trailLabelFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.bottom, 6)

                        Spacer(minLength: 0)
                    }

                    HStack(spacing: max(size.width * 0.025, 10)) {
                        ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(metric.value)
                                    .font(.system(size: metricValueFontSize, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.52)

                                Text(metric.title)
                                    .font(.system(size: metricLabelFontSize, weight: .semibold, design: .rounded))
                                    .foregroundStyle(accentColor.opacity(0.9))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, max(size.height * 0.024, 14))
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.34),
                            Color.black.opacity(0.72)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .animation(.spring(response: 0.36, dampingFraction: 0.82), value: showOverlays)
        }
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
}
