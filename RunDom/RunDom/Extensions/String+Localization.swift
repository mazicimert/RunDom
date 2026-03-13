import Foundation

extension String {
    var localized: String {
        LocalizationManager.shared.localizedString(forKey: self)
    }

    func localized(with arguments: CVarArg...) -> String {
        let format = LocalizationManager.shared.localizedString(forKey: self)
        return String(
            format: format,
            locale: LocalizationManager.shared.locale,
            arguments: arguments
        )
    }
}
