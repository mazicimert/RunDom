import Foundation

/// External (Notion-hosted) legal & help documents, opened in an in-app browser
/// (`SafariView`). Each document has a published Turkish and English Notion URL.
/// Language rule: Turkish app language → Turkish page; everything else → English.
///
/// IMPORTANT: The URLs below are placeholders. Each Notion page must be
/// "Published to web" (Share → Publish) so it has a public `*.notion.site` URL,
/// then paste that public URL here. Until then, the links will not open.
enum LegalLink: String, CaseIterable, Identifiable {
    case communityGuidelines
    case termsOfUse
    case privacyPolicy
    case helpCenter

    var id: String { rawValue }

    var titleLocalizationKey: String {
        switch self {
        case .communityGuidelines: return "legal.communityGuidelines.title"
        case .termsOfUse:          return "legal.termsOfUse.title"
        case .privacyPolicy:       return "legal.privacyPolicy.title"
        case .helpCenter:          return "legal.helpCenter.title"
        }
    }

    var iconName: String {
        switch self {
        case .communityGuidelines: return "person.3.fill"
        case .termsOfUse:          return "doc.text.fill"
        case .privacyPolicy:       return "lock.fill"
        case .helpCenter:          return "questionmark.circle.fill"
        }
    }

    /// The published Notion URL for the active app language.
    /// Turkish (`tr*`) → Turkish page; any other language → English page.
    func url(languageCode: String) -> URL? {
        let isTurkish = languageCode.lowercased().hasPrefix("tr")
        return URL(string: isTurkish ? turkishURLString : englishURLString)
    }

    // MARK: - Published Notion URLs (replace placeholders after publishing)

    private var turkishURLString: String {
        switch self {
        case .communityGuidelines: return "https://ultra-raft-5b2.notion.site/Topluluk-Kurallar-TR-380badec4fa48126ba7ada72011c093a"
        case .termsOfUse:          return "https://ultra-raft-5b2.notion.site/Kullan-m-artlar-TR-380badec4fa48199b05ed507b145e4f6"
        case .privacyPolicy:       return "https://ultra-raft-5b2.notion.site/Gizlilik-Politikas-TR-380badec4fa481a1af4ddb7429d2999c"
        case .helpCenter:          return "https://ultra-raft-5b2.notion.site/Yard-m-Merkezi-TR-380badec4fa481f59aedff3f0a02f896"
        }
    }

    private var englishURLString: String {
        switch self {
        case .communityGuidelines: return "https://ultra-raft-5b2.notion.site/Community-Guidelines-EN-380badec4fa4819abdd3dba260e1a86a"
        case .termsOfUse:          return "https://ultra-raft-5b2.notion.site/Terms-of-Use-EN-380badec4fa48161bfdcc82d22114aea"
        case .privacyPolicy:       return "https://ultra-raft-5b2.notion.site/Privacy-Policy-EN-380badec4fa481679441fd0238d77ed6"
        case .helpCenter:          return "https://ultra-raft-5b2.notion.site/Help-Center-EN-380badec4fa4819aaaa9c6735f50e3c3"
        }
    }
}
