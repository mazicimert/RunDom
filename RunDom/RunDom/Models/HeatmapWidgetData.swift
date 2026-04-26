import Foundation

struct HeatmapWidgetData: Codable, Equatable {
    static let dayCount = 84

    var intensities: [Int]
    var userColorHex: String

    static let empty = HeatmapWidgetData(
        intensities: Array(repeating: 0, count: HeatmapWidgetData.dayCount),
        userColorHex: "#4ECDC4"
    )
}
