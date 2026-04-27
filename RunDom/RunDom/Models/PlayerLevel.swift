import Foundation

/// Runner level progression derived from accumulated Trail points.
///
/// Reaching level N requires `250 · N · (N - 1)` total Trail. The gap between
/// consecutive levels grows linearly: `level · 500`.
struct PlayerLevel: Equatable {
    let level: Int
    let totalTrail: Double
    let currentThreshold: Double
    let nextThreshold: Double

    init(totalTrail: Double) {
        let trail = max(0, totalTrail)
        var currentLevel = 1
        var current = 0.0
        var next = Self.gap(forLevel: currentLevel)

        while trail >= next {
            currentLevel += 1
            current = next
            next += Self.gap(forLevel: currentLevel)
        }

        self.level = currentLevel
        self.totalTrail = trail
        self.currentThreshold = current
        self.nextThreshold = next
    }

    var remaining: Double {
        max(0, nextThreshold - totalTrail)
    }

    var fraction: Double {
        let span = max(1, nextThreshold - currentThreshold)
        return min(1, max(0, (totalTrail - currentThreshold) / span))
    }

    /// Total Trail required to reach the start of `level`.
    static func threshold(for level: Int) -> Double {
        guard level > 1 else { return 0 }
        let n = Double(level)
        return 250.0 * n * (n - 1)
    }

    /// Trail span between `level` and `level + 1`.
    static func gap(forLevel level: Int) -> Double {
        Double(level) * 500.0
    }
}
