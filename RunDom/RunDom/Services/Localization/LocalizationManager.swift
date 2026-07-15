import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case turkish = "tr"
    case portuguese = "pt-BR"
    case spanish = "es"
    case german = "de"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .turkish: return "Türkçe"
        case .portuguese: return "Português (Brasil)"
        case .spanish: return "Español"
        case .german: return "Deutsch"
        }
    }
}

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var selectedLanguageCode: String {
        didSet {
            guard selectedLanguageCode != oldValue else { return }
            guard AppLanguage(rawValue: selectedLanguageCode) != nil else {
                selectedLanguageCode = oldValue
                return
            }
            UserDefaults.standard.set(
                selectedLanguageCode,
                forKey: AppConstants.UserDefaultsKeys.appLanguageCode
            )
            UserDefaults.standard.set(
                true,
                forKey: AppConstants.UserDefaultsKeys.appLanguageManuallySelected
            )
        }
    }

    var locale: Locale {
        Locale(identifier: selectedLanguageCode)
    }

    var bundle: Bundle {
        Self.bundle(for: selectedLanguageCode)
    }

    private init() {
        let savedCode = UserDefaults.standard.string(
            forKey: AppConstants.UserDefaultsKeys.appLanguageCode
        )
        let initialCode = Self.resolveInitialLanguageCode(savedCode: savedCode)
        self.selectedLanguageCode = initialCode
    }

    func localizedString(forKey key: String, table: String? = nil) -> String {
        bundle.localizedString(forKey: key, value: nil, table: table)
    }

    static func localizedStringInAllLanguages(forKey key: String) -> Set<String> {
        var values: Set<String> = []
        for language in AppLanguage.allCases {
            let bundle = Self.bundle(for: language.rawValue)
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key {
                values.insert(value)
            }
        }
        return values
    }

    private static func resolveInitialLanguageCode(savedCode: String?) -> String {
        let hasManualSelection = UserDefaults.standard.bool(
            forKey: AppConstants.UserDefaultsKeys.appLanguageManuallySelected
        )
        let hasCompletedOnboarding = UserDefaults.standard.bool(
            forKey: AppConstants.UserDefaultsKeys.isOnboardingComplete
        )

        if let savedCode,
           AppLanguage(rawValue: savedCode) != nil,
           hasManualSelection || hasCompletedOnboarding {
            return savedCode
        }

        for preferred in Locale.preferredLanguages {
            if let match = matchSupportedLanguage(for: preferred) {
                return match.rawValue
            }
        }

        return AppLanguage.english.rawValue
    }

    private static func matchSupportedLanguage(for preferredLanguage: String) -> AppLanguage? {
        if let exact = AppLanguage(rawValue: preferredLanguage) {
            return exact
        }

        let normalized = preferredLanguage.replacingOccurrences(of: "_", with: "-")
        if let exact = AppLanguage(rawValue: normalized) {
            return exact
        }

        let primary = normalized.split(separator: "-").first.map(String.init) ?? normalized

        switch primary {
        case "en": return .english
        case "tr": return .turkish
        case "pt": return .portuguese
        case "es": return .spanish
        case "de": return .german
        default: return nil
        }
    }

    private static func bundle(for languageCode: String) -> Bundle {
        let mainBundle = Bundle.main

        if let path = mainBundle.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        if let path = mainBundle.path(
            forResource: languageCode,
            ofType: "lproj",
            inDirectory: "Localization"
        ), let bundle = Bundle(path: path) {
            return bundle
        }

        return mainBundle
    }
}
