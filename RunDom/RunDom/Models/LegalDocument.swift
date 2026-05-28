import Foundation

enum LegalDocument: String, CaseIterable, Identifiable {
    case communityGuidelines
    case termsOfUse

    var id: String { rawValue }

    // Bumping these forces a re-acceptance the next time the user tries to
    // post. Keep this in sync with the `Version:` line at the top of the
    // bundled markdown files.
    static let currentTermsVersion = 1

    var titleLocalizationKey: String {
        switch self {
        case .communityGuidelines: return "legal.communityGuidelines.title"
        case .termsOfUse:          return "legal.termsOfUse.title"
        }
    }

    /// Loads the markdown body for the requested document, picking the file
    /// that matches the active language and falling back to English. Returns
    /// the raw markdown — render with `AttributedString(markdown:)`.
    func loadMarkdown(languageCode: String) -> String {
        let suffix: String
        switch self {
        case .communityGuidelines: suffix = "community-guidelines"
        case .termsOfUse:          suffix = "terms-of-use"
        }

        let preferred = "\(suffix)-\(languageCode)"
        let fallback = "\(suffix)-en"

        for name in [preferred, fallback] {
            if let url = Bundle.main.url(forResource: name, withExtension: "md"),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }

        // Should never happen if the bundle includes both -tr and -en files,
        // but degrade gracefully instead of crashing.
        return ""
    }
}
