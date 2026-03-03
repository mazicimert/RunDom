import Foundation
import FirebaseRemoteConfig

final class RemoteConfigService {
    private let remoteConfig = RemoteConfig.remoteConfig()

    init() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600
        remoteConfig.configSettings = settings
        setDefaults()
    }

    // MARK: - Defaults

    private func setDefaults() {
        remoteConfig.setDefaults([
            "min_speed_kmh": NSNumber(value: AppConstants.Game.minSpeedKmh),
            "max_speed_kmh": NSNumber(value: AppConstants.Game.maxSpeedKmh),
            "boost_min_speed_kmh": NSNumber(value: AppConstants.Game.boostMinSpeedKmh),
            "boost_mode_multiplier": NSNumber(value: AppConstants.Game.boostModeMultiplier),
            "max_trail_per_run": NSNumber(value: AppConstants.Game.maxTrailPerRun),
            "max_trail_per_day": NSNumber(value: AppConstants.Game.maxTrailPerDay),
            "defense_decay_hours": NSNumber(value: AppConstants.Game.defenseDecayHours),
            "base_point_multiplier": NSNumber(value: AppConstants.Game.basePointMultiplier),
            "h3_resolution": NSNumber(value: AppConstants.Location.h3Resolution),
            "dropzone_reward_multiplier": NSNumber(value: AppConstants.Game.dropzoneRewardMultiplier),
            "dropzone_reward_days": NSNumber(value: AppConstants.Game.dropzoneRewardDays)
        ])
    }

    // MARK: - Fetch

    func fetchAndActivate() async throws {
        let status = try await remoteConfig.fetchAndActivate()
        AppLogger.firebase.info("Remote Config status: \(status.rawValue)")
    }

    // MARK: - Getters

    var minSpeedKmh: Double {
        remoteConfig["min_speed_kmh"].numberValue.doubleValue
    }

    var maxSpeedKmh: Double {
        remoteConfig["max_speed_kmh"].numberValue.doubleValue
    }

    var boostMinSpeedKmh: Double {
        remoteConfig["boost_min_speed_kmh"].numberValue.doubleValue
    }

    var boostModeMultiplier: Double {
        remoteConfig["boost_mode_multiplier"].numberValue.doubleValue
    }

    var maxTrailPerRun: Double {
        remoteConfig["max_trail_per_run"].numberValue.doubleValue
    }

    var maxTrailPerDay: Double {
        remoteConfig["max_trail_per_day"].numberValue.doubleValue
    }

    var defenseDecayHours: Int {
        remoteConfig["defense_decay_hours"].numberValue.intValue
    }

    var basePointMultiplier: Double {
        remoteConfig["base_point_multiplier"].numberValue.doubleValue
    }

    var h3Resolution: Int {
        remoteConfig["h3_resolution"].numberValue.intValue
    }

    var dropzoneRewardMultiplier: Double {
        remoteConfig["dropzone_reward_multiplier"].numberValue.doubleValue
    }

    var dropzoneRewardDays: Int {
        remoteConfig["dropzone_reward_days"].numberValue.intValue
    }
}
