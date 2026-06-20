import SwiftUI
import SafariServices

/// Thin SwiftUI wrapper around `SFSafariViewController`. Presents a web page
/// (e.g. a published Notion legal/help document) in an in-app browser so the
/// user never fully leaves the app. Present it via `.sheet(item:)`.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.barCollapsingEnabled = true
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
