import Foundation

struct AIRunAnalysis: Codable, Equatable, Hashable {
    let runSummary: String
    let highlights: [String]
    let aiCommentary: String
    let nextSuggestion: String
}

enum AIAnalysisSource: String, Codable, Equatable {
    case ai
    case template
}

struct AIRunAnalysisResult: Equatable {
    let analysis: AIRunAnalysis
    let source: AIAnalysisSource
}
