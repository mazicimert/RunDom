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

    var formattedDistance: String {
        formattedDistance()
    }

    var formattedDistanceFromMeters: String {
        formattedDistanceFromMeters()
    }

    var formattedSpeed: String {
        formattedSpeed()
    }

    var formattedCompactDistanceValueFromMeters: String {
        formattedCompactDistanceValueFromMeters()
    }

    var formattedCompactSpeedValue: String {
        formattedCompactSpeedValue()
    }

    func formattedDecimal(maxFractionDigits: Int, minFractionDigits: Int = 0) -> String {
        let formatter = FormatterCache.decimal(max: maxFractionDigits, min: minFractionDigits)
        formatter.locale = appLocale
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    var formattedPace: String {
        formattedPace()
    }

    func formattedDistance(useMiles: Bool = UnitPreference.shared.useMiles) -> String {
        let value = UnitPreference.distanceValue(fromKilometers: self, useMiles: useMiles)
        return String(
            format: "%.2f %@",
            locale: appLocale,
            value,
            UnitPreference.distanceUnitLabel(useMiles: useMiles)
        )
    }

    func formattedDistanceFromMeters(useMiles: Bool = UnitPreference.shared.useMiles) -> String {
        (self / 1000.0).formattedDistance(useMiles: useMiles)
    }

    func formattedSpeed(useMiles: Bool = UnitPreference.shared.useMiles) -> String {
        let value = UnitPreference.speedValue(fromKilometersPerHour: self, useMiles: useMiles)
        return String(
            format: "%.1f %@",
            locale: appLocale,
            value,
            UnitPreference.speedUnitLabel(useMiles: useMiles)
        )
    }

    func formattedCompactDistanceValueFromMeters(
        useMiles: Bool = UnitPreference.shared.useMiles
    ) -> String {
        let value = UnitPreference.distanceValue(
            fromKilometers: self / 1000.0,
            useMiles: useMiles
        )
        return String(format: "%.2f", locale: appLocale, value)
    }

    func formattedCompactSpeedValue(useMiles: Bool = UnitPreference.shared.useMiles) -> String {
        let value = UnitPreference.speedValue(fromKilometersPerHour: self, useMiles: useMiles)
        return String(format: "%.1f", locale: appLocale, value)
    }

    func formattedPace(useMiles: Bool = UnitPreference.shared.useMiles) -> String {
        guard self > 0 else { return "--" }
        let paceValue = UnitPreference.paceValue(fromKilometersPerHour: self, useMiles: useMiles)
        let totalSeconds = Int((paceValue * 60).rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d'%02d\"", locale: appLocale, minutes, seconds)
    }

    var formattedTrail: String {
        let formatter = FormatterCache.trail
        formatter.locale = appLocale
        return formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
    }

    var formattedPercentChange: String {
        let sign = self >= 0 ? "+" : ""
        return String(format: "%@%.0f%%", locale: appLocale, sign, self)
    }
}
