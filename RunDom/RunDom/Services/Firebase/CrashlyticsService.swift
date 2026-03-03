import Foundation
import FirebaseCrashlytics

enum CrashlyticsService {
    static func setUserId(_ userId: String) {
        Crashlytics.crashlytics().setUserID(userId)
    }

    static func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    static func recordError(_ error: Error, userInfo: [String: Any]? = nil) {
        if let info = userInfo {
            Crashlytics.crashlytics().record(error: error, userInfo: info)
        } else {
            Crashlytics.crashlytics().record(error: error)
        }
        AppLogger.firebase.error("Crashlytics error: \(error.localizedDescription)")
    }

    static func setCustomValue(_ value: Any, forKey key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
}
