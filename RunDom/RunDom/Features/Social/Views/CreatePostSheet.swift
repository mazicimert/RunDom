import SwiftUI
import PhotosUI

struct CreatePostSheet: View {
    let session: RunSession
    let author: User
    let onPublished: (Post) -> Void

    @EnvironmentObject private var appState: AppState
    @ObservedObject private var privacyZonesStore = PrivacyZonesStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var caption: String = ""
    @State private var visibility: PostVisibility = .followers
    @State private var isPublishing = false
    @State private var errorMessage: String?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isLoadingPhotos = false
    @State private var showLegalGate = false

    private let postService = PostService()
    private let maxCaptionLength = 280
    private var maxPhotos: Int { AppConstants.PostPhoto.maxCount }

    private var needsLegalAcceptance: Bool {
        let acceptedVersion = appState.currentUser?.acceptedTermsVersion ?? 0
        return acceptedVersion < LegalDocument.currentTermsVersion
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    runPreviewCard
                    photosSection
                    captionField
                    visibilityPicker
                    if !privacyZonesStore.isEmpty {
                        privacyZonesBanner
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.vertical, 20)
            }
            .background(Color.surfacePrimary.ignoresSafeArea())
            .navigationTitle("social.create.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("social.create.cancel".localized) {
                        dismiss()
                    }
                    .disabled(isPublishing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        publish()
                    } label: {
                        if isPublishing {
                            ProgressView()
                        } else {
                            Text("social.create.publish".localized)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isPublishing || isLoadingPhotos)
                }
            }
            .onChange(of: pickerItems) { _, newItems in
                Task { await loadPhotos(from: newItems) }
            }
            .sheet(isPresented: $showLegalGate) {
                LegalAcceptanceSheet {
                    // After acceptance the gate auto-dismisses; continue with
                    // the publish that triggered the gate.
                    runPublish()
                }
                .environmentObject(appState)
            }
        }
    }

    private var runPreviewCard: some View {
        HStack(spacing: 14) {
            AvatarView(
                photoURL: author.photoURL,
                userColor: author.color,
                size: 48
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(author.displayName)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 6) {
                    Text(session.distance.formattedDistanceFromMeters)
                        .font(.caption.weight(.semibold))
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("trail.points".localized(with: session.trail.formattedTrail))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardBackground)
        )
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("social.create.photos.label".localized)
                    .font(.subheadline.weight(.semibold))
                Text("(\(selectedImages.count)/\(maxPhotos))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                        photoThumbnail(image: image, index: index)
                    }

                    if selectedImages.count < maxPhotos {
                        addPhotoButton
                    }
                }
                .padding(.vertical, 2)
            }

            Text("social.create.photos.hint".localized)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func photoThumbnail(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                removePhoto(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white, .black.opacity(0.65))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .disabled(isPublishing)
            .accessibilityLabel("social.create.photos.remove".localized)
        }
    }

    private var addPhotoButton: some View {
        PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: maxPhotos - selectedImages.count,
            selectionBehavior: .ordered,
            matching: .images,
            photoLibrary: .shared()
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.cardBackground)
                    .frame(width: 92, height: 92)

                VStack(spacing: 4) {
                    if isLoadingPhotos {
                        ProgressView()
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 24, weight: .medium))
                        Text("social.create.photos.add".localized)
                            .font(.caption2.weight(.semibold))
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .disabled(isPublishing || isLoadingPhotos)
    }

    private var captionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                "social.create.caption.placeholder".localized,
                text: $caption,
                axis: .vertical
            )
            .lineLimit(3...8)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.cardBackground)
            )
            .onChange(of: caption) { _, newValue in
                if newValue.count > maxCaptionLength {
                    caption = String(newValue.prefix(maxCaptionLength))
                }
            }

            HStack {
                Spacer()
                Text("\(caption.count)/\(maxCaptionLength)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var privacyZonesBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("privacy.zones.banner.title".localized(with: "\(privacyZonesStore.zones.count)"))
                    .font(.subheadline.weight(.semibold))
                Text("privacy.zones.banner.subtitle".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var visibilityPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("social.create.visibility.label".localized)
                .font(.subheadline.weight(.semibold))

            Picker("social.create.visibility.label".localized, selection: $visibility) {
                Text("social.create.visibility.followers".localized)
                    .tag(PostVisibility.followers)
                Text("social.create.visibility.public".localized)
                    .tag(PostVisibility.public)
            }
            .pickerStyle(.segmented)
            .disabled(isPublishing)
        }
    }

    // MARK: - Actions

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isLoadingPhotos = true

        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loaded.append(image)
            }
        }

        let combined = selectedImages + loaded
        selectedImages = Array(combined.prefix(maxPhotos))
        pickerItems = []
        isLoadingPhotos = false
    }

    private func removePhoto(at index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages.remove(at: index)
    }

    private func publish() {
        // Gate: never let a post go out unless the user has accepted the
        // current version of the legal docs.
        if needsLegalAcceptance {
            showLegalGate = true
            return
        }
        runPublish()
    }

    private func runPublish() {
        isPublishing = true
        errorMessage = nil
        Task {
            do {
                let post = try await postService.createPost(
                    from: session,
                    author: author,
                    caption: caption.isEmpty ? nil : caption,
                    visibility: visibility,
                    images: selectedImages
                )
                Haptics.notification(.success)
                onPublished(post)
                dismiss()
            } catch {
                AppLogger.firebase.error("Failed to publish post: \(error.localizedDescription)")
                errorMessage = "social.create.error".localized
                isPublishing = false
            }
        }
    }
}
