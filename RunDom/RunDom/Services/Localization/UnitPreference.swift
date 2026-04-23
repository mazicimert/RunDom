import Combine
import Foundation

final class UnitPreference: ObservableObject {
    static let shared = UnitPreference()
    static let milesPerKilometer = 0.621371

    @Published var useMiles: Bool {
        didSet {
            guard useMiles != oldValue else { return }
            UserDefaults.standard.set(
                useMiles,
                forKey: AppConstants.UserDefaultsKeys.unitPreference
            )
        }
    }

    var distanceUnitLabel: String {
        Self.distanceUnitLabel(useMiles: useMiles)
    }

    var speedUnitLabel: String {
        Self.speedUnitLabel(useMiles: useMiles)
    }

    var paceUnitLabel: String {
        Self.paceUnitLabel(useMiles: useMiles)
    }

    private init() {
        let savedPreference = UserDefaults.standard.object(
            forKey: AppConstants.UserDefaultsKeys.unitPreference
        ) as? Bool
        self.useMiles = savedPreference ?? false
    }

    static func distanceValue(fromKilometers value: Double, useMiles: Bool) -> Double {
        useMiles ? value * milesPerKilometer : value
    }

    static func speedValue(fromKilometersPerHour value: Double, useMiles: Bool) -> Double {
        useMiles ? value * milesPerKilometer : value
    }

    static func paceValue(fromKilometersPerHour value: Double, useMiles: Bool) -> Double {
        let paceMinPerKilometer = 60.0 / value
        return useMiles ? paceMinPerKilometer / milesPerKilometer : paceMinPerKilometer
    }

    static func distanceUnitLabel(useMiles: Bool) -> String {
        (useMiles ? "unit.distance.mi" : "unit.distance.km").localized
    }

    static func speedUnitLabel(useMiles: Bool) -> String {
        (useMiles ? "unit.speed.mph" : "unit.speed.kmh").localized
    }

    static func paceUnitLabel(useMiles: Bool) -> String {
        (useMiles ? "unit.pace.mi" : "unit.pace.km").localized
    }
}
