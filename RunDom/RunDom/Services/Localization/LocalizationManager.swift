import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case turkish = "tr"
    case english = "en"

    var id: String { rawValue }
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

    private static func resolveInitialLanguageCode(savedCode: String?) -> String {
        if let savedCode, AppLanguage(rawValue: savedCode) != nil {
            return savedCode
        }

        if let preferred = Locale.preferredLanguages.first {
            let languageCode = String(preferred.prefix(2))
            if AppLanguage(rawValue: languageCode) != nil {
                return languageCode
            }
        }

        return AppLanguage.turkish.rawValue
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
