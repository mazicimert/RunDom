import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.mertmazici.RunDom"

    static let location = Logger(subsystem: subsystem, category: "Location")
    static let firebase = Logger(subsystem: subsystem, category: "Firebase")
    static let game = Logger(subsystem: subsystem, category: "Game")
    static let run = Logger(subsystem: subsystem, category: "Run")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let notification = Logger(subsystem: subsystem, category: "Notification")
    static let sync = Logger(subsystem: subsystem, category: "Sync")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let general = Logger(subsystem: subsystem, category: "General")
}
