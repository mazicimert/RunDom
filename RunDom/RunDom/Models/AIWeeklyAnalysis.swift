import Foundation

struct AIWeeklyAnalysis: Codable, Equatable, Hashable {
    let weekTrend: String
    let topAchievement: String
    let weakPoint: String
    let nextWeekFocus: String
}

struct AIWeeklyAnalysisResult: Equatable {
    let analysis: AIWeeklyAnalysis
    let source: AIAnalysisSource
}
