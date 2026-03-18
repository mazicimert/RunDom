import Foundation

enum DailyChallengeMetricType: String, Codable, CaseIterable {
    case durationMinutes
    case distanceMeters

    func localizedTitle(targetValue: Double) -> String {
        switch self {
        case .durationMinutes:
            return "challenge.duration.title".localized(with: Int(targetValue.rounded()))
        case .distanceMeters:
            return "challenge.distance.title".localized(with: formattedValue(targetValue))
        }
    }

    func formattedValue(_ value: Double) -> String {
        switch self {
        case .durationMinutes:
            return "challenge.duration.value".localized(with: Int(value.rounded()))
        case .distanceMeters:
            let locale = LocalizationManager.shared.locale
            let kilometers = value / 1000.0
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = kilometers.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
            formatter.maximumFractionDigits = formatter.minimumFractionDigits
            formatter.locale = locale
            let number = formatter.string(from: NSNumber(value: kilometers)) ?? String(format: "%.1f", locale: locale, kilometers)
            return "challenge.distance.value".localized(with: number)
        }
    }
}

enum DailyChallengeDifficulty: String, Codable, CaseIterable {
    case safe
    case difficult

    var localizedLabel: String {
        switch self {
        case .safe:
            return "challenge.difficulty.safe".localized
        case .difficult:
            return "challenge.difficulty.difficult".localized
        }
    }
}

struct DailyChallengeTemplate: Codable, Identifiable, Equatable {
    let id: String
    var titleKey: String?
    var title: String?
    let metricType: DailyChallengeMetricType
    let targetValue: Double
    let bonusTrail: Double
    let difficulty: DailyChallengeDifficulty
    var isActive: Bool = true
    var sortOrder: Int = 0

    var localizedTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }

        if let titleKey {
            let localized = titleKey.localized
            if localized != titleKey {
                return localized
            }
        }

        return metricType.localizedTitle(targetValue: targetValue)
    }

    var rewardText: String {
        "challenge.reward.value".localized(with: bonusTrail.formattedTrail)
    }

    var targetText: String {
        metricType.formattedValue(targetValue)
    }

    func progressFraction(for progressValue: Double) -> Double {
        guard targetValue > 0 else { return 0 }
        return min(max(progressValue / targetValue, 0), 1.0)
    }

    func progressText(for progressValue: Double) -> String {
        let clampedProgress = min(max(progressValue, 0), targetValue)
        return "challenge.progress.value".localized(
            with: metricType.formattedValue(clampedProgress),
            metricType.formattedValue(targetValue)
        )
    }
}

struct UserDailyChallengeProgress: Codable, Identifiable, Equatable {
    var id: String { dateKey }

    let dateKey: String
    var safeChallengeId: String
    var difficultChallengeId: String
    var selectedChallengeId: String?
    var progressValue: Double = 0
    var isCompleted: Bool = false
    var rewardGranted: Bool = false
    var completedAt: Date?
    var completedRunId: String?
}

struct DailyChallengeState: Equatable {
    let dateKey: String
    let safeChallenge: DailyChallengeTemplate
    let difficultChallenge: DailyChallengeTemplate
    let progress: UserDailyChallengeProgress?

    var challenges: [DailyChallengeTemplate] {
        [safeChallenge, difficultChallenge]
    }

    var selectedChallenge: DailyChallengeTemplate? {
        guard let selectedId = progress?.selectedChallengeId else { return nil }
        return challenges.first(where: { $0.id == selectedId })
    }

    func progressValue(for challenge: DailyChallengeTemplate) -> Double {
        guard progress?.selectedChallengeId == challenge.id else { return 0 }
        return progress?.progressValue ?? 0
    }

    func isSelected(_ challenge: DailyChallengeTemplate) -> Bool {
        progress?.selectedChallengeId == challenge.id
    }

    func isLocked(_ challenge: DailyChallengeTemplate) -> Bool {
        guard let selectedId = progress?.selectedChallengeId else { return false }
        return selectedId != challenge.id
    }
}

struct DailyChallengeReward: Equatable {
    let challengeTitle: String
    let bonusTrail: Double
}
