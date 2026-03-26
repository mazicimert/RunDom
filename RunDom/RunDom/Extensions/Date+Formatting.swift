import Foundation

extension Date {
    private var appLocale: Locale {
        LocalizationManager.shared.locale
    }

    func formatted(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        formatter.locale = appLocale
        return formatter.string(from: self)
    }

    func formattedTime(style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = style
        formatter.locale = appLocale
        return formatter.string(from: self)
    }

    func formattedDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = appLocale
        return formatter.string(from: self)
    }

    func formattedHistoryWeekday() -> String {
        let formatter = DateFormatter()
        formatter.locale = appLocale
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: self)
            .replacingOccurrences(of: ".", with: "")
            .uppercased(with: appLocale)
    }

    func formattedHistoryDayMonth() -> String {
        let formatter = DateFormatter()
        formatter.locale = appLocale
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: self)
    }

    func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = appLocale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

extension TimeInterval {
    var formattedDuration: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
