import Foundation

enum WeeklyRunGoal: Int, Codable, CaseIterable, Identifiable {
    case two = 2
    case four = 4
    case six = 6
    case daily = 7

    var id: Int { rawValue }

    var localizationKey: String {
        switch self {
        case .two: return "runnerProfile.weeklyGoal.two"
        case .four: return "runnerProfile.weeklyGoal.four"
        case .six: return "runnerProfile.weeklyGoal.six"
        case .daily: return "runnerProfile.weeklyGoal.daily"
        }
    }
}

enum RunnerMotivation: String, Codable, CaseIterable, Identifiable {
    case competition
    case health
    case exploration
    case mindClearing

    var id: String { rawValue }

    var localizationKey: String {
        "runnerProfile.motivation.\(rawValue)"
    }
}

enum RunnerExperience: String, Codable, CaseIterable, Identifiable {
    case beginner
    case casual
    case regular
    case competitive

    var id: String { rawValue }

    var localizationKey: String {
        "runnerProfile.experience.\(rawValue)"
    }
}

struct RunnerProfile: Codable, Equatable {
    var weeklyGoal: WeeklyRunGoal?
    var motivation: RunnerMotivation?
    var experience: RunnerExperience?
    var preferredMode: RunMode?

    var isComplete: Bool {
        weeklyGoal != nil && motivation != nil && experience != nil && preferredMode != nil
    }
}
