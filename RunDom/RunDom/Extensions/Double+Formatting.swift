import Foundation

private enum FormatterCache {
    static let trail: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static func decimal(max: Int, min: Int) -> NumberFormatter {
        let key = "\(max)-\(min)"
        if let cached = decimalCache[key] { return cached }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = max
        f.minimumFractionDigits = min
        decimalCache[key] = f
        return f
    }

    private static var decimalCache: [String: NumberFormatter] = [:]
}

extension Double {
    private var appLocale: Locale {
        LocalizationManager.shared.locale
    }

    /// Formats as distance in kilometers (e.g. "3.24 km")
    var formattedDistance: String {
        String(format: "%.2f km", locale: appLocale, self)
    }

    /// Formats distance stored in meters as kilometers (e.g. 3240 -> "3.24 km")
    var formattedDistanceFromMeters: String {
        (self / 1000.0).formattedDistance
    }

    /// Formats as speed in km/h (e.g. "8.5 km/h")
    var formattedSpeed: String {
        String(format: "%.1f km/h", locale: appLocale, self)
    }

    /// Formats meters as compact kilometer value without a unit (e.g. 3240 -> "3.24")
    var formattedCompactDistanceValueFromMeters: String {
        String(format: "%.2f", locale: appLocale, self / 1000.0)
    }

    /// Formats as compact speed value without a unit (e.g. "8.5")
    var formattedCompactSpeedValue: String {
        String(format: "%.1f", locale: appLocale, self)
    }

    func formattedDecimal(maxFractionDigits: Int, minFractionDigits: Int = 0) -> String {
        let formatter = FormatterCache.decimal(max: maxFractionDigits, min: minFractionDigits)
        formatter.locale = appLocale
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    /// Formats as pace in min/km (e.g. "5'30\"")
    var formattedPace: String {
        guard self > 0 else { return "--" }
        let paceMinPerKm = 60.0 / self
        let minutes = Int(paceMinPerKm)
        let seconds = Int((paceMinPerKm - Double(minutes)) * 60)
        return String(format: "%d'%02d\"", locale: appLocale, minutes, seconds)
    }

    /// Formats as Trail points (e.g. "1,250")
    var formattedTrail: String {
        let formatter = FormatterCache.trail
        formatter.locale = appLocale
        return formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
    }

    /// Formats as percentage (e.g. "+12%")
    var formattedPercentChange: String {
        let sign = self >= 0 ? "+" : ""
        return String(format: "%@%.0f%%", locale: appLocale, sign, self)
    }
}
