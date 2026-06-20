import UIKit

/// Exports a rendered share card to a temporary JPEG file.
///
/// Share extensions (WhatsApp, Instagram, …) run with a tight memory budget.
/// Handing them a large in-memory `UIImage` through `UIActivityViewController`
/// forces the bitmap across XPC and can get the extension jettisoned mid-share
/// ("Connection to plugin invalidated while in use"), bouncing the user back to
/// the app. Sharing a file URL instead lets the extension stream the JPEG from
/// disk, which is dramatically lighter and reliable.
enum ShareImageExporter {
    /// Writes `image` as a JPEG into the temporary directory and returns its URL.
    /// Returns `nil` if encoding or writing fails.
    static func temporaryJPEGURL(
        for image: UIImage,
        compressionQuality: CGFloat = 0.9
    ) -> URL? {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            AppLogger.run.error("Share export failed: could not encode JPEG")
            return nil
        }

        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("RunPire-\(UUID().uuidString).jpg")

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            AppLogger.run.error("Share export failed: \(error.localizedDescription)")
            return nil
        }
    }
}
