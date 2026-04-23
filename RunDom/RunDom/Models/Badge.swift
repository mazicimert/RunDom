import Foundation

enum BadgeCategory: String, Codable, CaseIterable {
    case performance
    case territory
    case dropzone
    case exploration
    case streak
}

struct Badge: Codable, Identifiable, Equatable {
    let id: String
    let nameKey: String
    let descriptionKey: String
    let iconName: String
    let category: BadgeCategory
    let isSecret: Bool
    var isUnlocked: Bool = false
    var unlockedAt: Date?
    var progress: Double = 0
    var targetValue: Double = 1

    var localizedName: String {
        resolvedLocalizedString(primaryKey: nameKey, fallbackKey: "badge.\(id).name")
    }

    var localizedDescription: String {
        if let localizedDistanceDescription {
            return localizedDistanceDescription
        }
        return resolvedLocalizedString(primaryKey: descriptionKey, fallbackKey: "badge.\(id).description")
    }

    var isDistanceBased: Bool {
        id.contains("distance")
    }

    var progressPercentage: Double {
        guard targetValue > 0 else { return 0 }
        return min(max(progress / targetValue, 0), 1.0)
    }

    var clampedProgress: Double {
        max(0, min(progress, targetValue))
    }

    var remainingProgress: Double {
        max(targetValue - max(progress, 0), 0)
    }

    var progressText: String {
        "\(formattedProgressValue(clampedProgress)) / \(formattedProgressValue(targetValue))"
    }

    var remainingText: String {
        formattedProgressValue(remainingProgress)
    }

    private func formattedProgressValue(_ value: Double) -> String {
        if isDistanceBased {
            return Self.formattedDistanceValue(value)
        }
        return String(Int(value.rounded(.down)))
    }

    private var localizedDistanceDescription: String? {
        guard isDistanceBased else { return nil }

        let format = LocalizationManager.shared.localizedString(forKey: descriptionKey)
        guard format != descriptionKey else { return nil }

        return String(
            format: format,
            locale: LocalizationManager.shared.locale,
            Self.formattedDistanceValue(targetValue)
        )
    }

    private static func formattedDistanceValue(_ value: Double) -> String {
        let distanceValue = UnitPreference.distanceValue(
            fromKilometers: value / 1000.0,
            useMiles: UnitPreference.shared.useMiles
        )
        let formattedValue = distanceValue.formattedDecimal(maxFractionDigits: 1, minFractionDigits: 1)
        return "\(formattedValue) \(UnitPreference.shared.distanceUnitLabel)"
    }

    private func resolvedLocalizedString(primaryKey: String, fallbackKey: String) -> String {
        let primary = primaryKey.localized
        if primary != primaryKey {
            return primary
        }

        let fallback = fallbackKey.localized
        if fallback != fallbackKey {
            return fallback
        }

        return Self.humanizedKey(primaryKey)
    }

    private static func humanizedKey(_ key: String) -> String {
        let sanitized = key
            .replacingOccurrences(of: "badge.", with: "")
            .replacingOccurrences(of: ".name", with: "")
            .replacingOccurrences(of: ".description", with: "")
            .replacingOccurrences(of: "_", with: " ")
        return sanitized.capitalized
    }
}
