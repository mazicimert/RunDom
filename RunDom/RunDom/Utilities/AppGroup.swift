import Foundation

enum AppGroup {
    #if DEBUG
    static let identifier = "group.com.mertmazici.RunDom.staging"
    #else
    static let identifier = "group.com.mertmazici.RunDom"
    #endif
    static let weeklySummaryKey = "weeklySummary"
    static let heatmapDataKey = "heatmapData"
}
