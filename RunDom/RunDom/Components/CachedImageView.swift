import SwiftUI
import UIKit

// MARK: - Image Cache

final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        memoryCache.countLimit = 50
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func image(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)

        // 1. Memory
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // 2. Disk
        let filePath = cacheDirectory.appendingPathComponent(key)
        if let data = try? Data(contentsOf: filePath),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
            return image
        }

        return nil
    }

    func store(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }

        memoryCache.setObject(image, forKey: key as NSString, cost: data.count)

        let filePath = cacheDirectory.appendingPathComponent(key)
        try? data.write(to: filePath)
    }

    private func cacheKey(for url: URL) -> String {
        url.absoluteString.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
    }
}

// MARK: - CachedImageView

struct CachedImageView: View {
    let url: URL
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                ProgressView()
            } else {
                // Failed
                Image(systemName: "person.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        // Check cache first
        if let cached = ImageCache.shared.image(for: url) {
            image = cached
            isLoading = false
            return
        }

        // Download
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloaded = UIImage(data: data) {
                ImageCache.shared.store(downloaded, for: url)
                image = downloaded
            }
        } catch {
            AppLogger.general.error("Image download failed: \(error.localizedDescription)")
        }

        isLoading = false
    }
}
