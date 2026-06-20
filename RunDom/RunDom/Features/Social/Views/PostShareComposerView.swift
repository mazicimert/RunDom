import SwiftUI
import UIKit
import ImageIO

struct PostShareComposerView: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIndex: Int = 0
    @State private var selectedTemplate: PostShareTemplate = .hero
    @State private var loadedImages: [Int: UIImage] = [:]
    @State private var isLoadingImages = false
    @State private var isRendering = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    private var photoURLs: [URL] {
        (post.photoURLs ?? []).compactMap(URL.init(string:))
    }

    private var hasPhotos: Bool { !photoURLs.isEmpty }

    private var cardPreviewWidth: CGFloat {
        UIScreen.main.bounds.width - 48
    }

    private var cardPreviewHeight: CGFloat {
        cardPreviewWidth * (1920.0 / 1080.0)
    }

    private var cardScale: CGFloat {
        cardPreviewWidth / 1080.0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    templatePickerRow
                        .padding(.horizontal, 24)
                    if hasPhotos && photoURLs.count > 1 {
                        photoPickerRow
                            .padding(.horizontal, 24)
                    }
                    cardPreviewContainer
                        .padding(.horizontal, 24)
                }
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .background(Color.surfacePrimary.ignoresSafeArea())
            .navigationTitle("common.share".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel".localized) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                shareButtonBar
            }
        }
        .task {
            await preloadImages()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }

    // MARK: - Template picker

    private var templatePickerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("social.externalShare.template".localized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            HStack(spacing: 8) {
                ForEach(PostShareTemplate.allCases) { template in
                    Button {
                        selectedTemplate = template
                    } label: {
                        Text(template.localizedName)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule().fill(
                                    selectedTemplate == template
                                        ? Color.accentColor
                                        : Color.cardBackground
                                )
                            )
                            .foregroundStyle(
                                selectedTemplate == template
                                    ? Color.white
                                    : Color.primary
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Photo picker

    private var photoPickerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("social.externalShare.selectPhoto".localized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(photoURLs.enumerated()), id: \.offset) { index, _ in
                        photoThumbnail(index: index)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private func photoThumbnail(index: Int) -> some View {
        Group {
            if let img = loadedImages[index] {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.cardBackground
                    .overlay(ProgressView().scaleEffect(0.7))
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    selectedIndex == index ? Color.accentColor : Color.clear,
                    lineWidth: 2.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedIndex = index }
    }

    // MARK: - Card preview

    private var cardPreviewContainer: some View {
        Color.clear
            .frame(width: cardPreviewWidth, height: cardPreviewHeight)
            .overlay(alignment: .topLeading) {
                PostShareCardView(
                    post: post,
                    photoImage: loadedImages[selectedIndex],
                    template: selectedTemplate
                )
                .frame(width: 1080, height: 1920)
                .scaleEffect(cardScale, anchor: .topLeading)
                // Force clean recreation per (photo, template) — diffing the deeply
                // nested Card layout was slower than a fresh build and caused the
                // freeze on photo switches.
                .id("\(selectedIndex)-\(selectedTemplate.rawValue)")
                // The preview must never intercept touches. Its native layout box
                // is 1080×1920 (only visually scaled), which would otherwise extend
                // far beyond the screen and swallow taps meant for the thumbnails
                // above it.
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(Rectangle())
            .shadow(color: .black.opacity(0.3), radius: 28, y: 12)
    }

    // MARK: - Share button bar

    private var shareButtonBar: some View {
        Button {
            Task { await renderAndShare() }
        } label: {
            HStack(spacing: 10) {
                if isRendering {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                }
                Text(isRendering
                     ? "social.externalShare.preparing".localized
                     : "common.share".localized)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isRendering || isLoadingImages ? Color.accentColor.opacity(0.5) : Color.accentColor)
            )
            .foregroundStyle(.white)
        }
        .disabled(isRendering || isLoadingImages)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial)
    }

    // MARK: - Image preloading

    @MainActor
    private func preloadImages() async {
        guard hasPhotos else { return }
        isLoadingImages = true
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, url) in photoURLs.enumerated() {
                group.addTask {
                    let image = await Self.downloadImage(url: url)
                    return (index, image)
                }
            }
            for await (index, image) in group {
                if let image { loadedImages[index] = image }
            }
        }
        isLoadingImages = false
    }

    private static func downloadImage(url: URL) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return downsample(data: data, maxPixelSize: 1800) ?? UIImage(data: data)
    }

    /// Memory-efficient downsampling via CGImageSource. Avoids loading the full
    /// resolution into memory; ImageRenderer at 1080×1920 doesn't need 4000px source.
    private static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let srcOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, srcOptions) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }

    // MARK: - Render & Share

    @MainActor
    private func renderAndShare() async {
        guard !isRendering else { return }
        isRendering = true

        let photoImage = hasPhotos ? loadedImages[selectedIndex] : nil
        let canvas = CGSize(width: 1080, height: 1920)

        let cardView = PostShareCardView(
            post: post,
            photoImage: photoImage,
            template: selectedTemplate
        )
        .frame(width: canvas.width, height: canvas.height)
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: cardView)
        renderer.proposedSize = ProposedViewSize(canvas)
        // 1080×1920 @ 2x (2160×3840) is ample for story/share quality while
        // keeping the bitmap far below the @3x size that overran extensions.
        renderer.scale = 2

        let rendered = renderer.uiImage
        isRendering = false

        guard let image = rendered,
              let fileURL = ShareImageExporter.temporaryJPEGURL(for: image) else { return }

        // Share the JPEG file URL (not the raw UIImage) so memory-constrained
        // share extensions like WhatsApp don't get jettisoned mid-share.
        shareItems = [fileURL]
        AnalyticsService.logPostExternalShare(
            postId: post.id,
            hasPhoto: hasPhotos,
            template: selectedTemplate.rawValue
        )
        showShareSheet = true
    }
}
