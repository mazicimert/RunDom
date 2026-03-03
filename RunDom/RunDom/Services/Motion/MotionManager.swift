import Foundation
import CoreMotion
import Combine

final class MotionManager: ObservableObject {

    // MARK: - Published State

    /// Indicates whether the user appears to be physically moving (accelerometer-based).
    @Published var isUserMoving = false

    /// Raw acceleration magnitude (1.0 = stationary, higher = movement).
    @Published var accelerationMagnitude: Double = 1.0

    // MARK: - Publishers

    /// Emits acceleration magnitude samples for anti-cheat cross-validation.
    let accelerationPublisher = PassthroughSubject<Double, Never>()

    // MARK: - Private

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var isRunning = false

    /// Threshold above which we consider the user to be physically moving.
    /// Stationary device ≈ 1.0g; walking/running produces fluctuations.
    private let movementThreshold: Double = 0.15

    /// Update interval in seconds (10 Hz).
    private let updateInterval: TimeInterval = 0.1

    // MARK: - Init

    init() {
        queue.name = "com.mertmazici.RunDom.motion"
        queue.maxConcurrentOperationCount = 1
    }

    // MARK: - Availability

    var isAccelerometerAvailable: Bool {
        motionManager.isAccelerometerAvailable
    }

    // MARK: - Start / Stop

    func startMonitoring() {
        guard !isRunning, isAccelerometerAvailable else { return }

        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, error in
            guard let self, let data else {
                if let error {
                    AppLogger.run.error("Accelerometer error: \(error.localizedDescription)")
                }
                return
            }

            let acc = data.acceleration
            let magnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
            let deviation = abs(magnitude - 1.0) // deviation from gravity

            DispatchQueue.main.async {
                self.accelerationMagnitude = magnitude
                self.isUserMoving = deviation > self.movementThreshold
                self.accelerationPublisher.send(magnitude)
            }
        }

        isRunning = true
        AppLogger.run.info("Motion monitoring started")
    }

    func stopMonitoring() {
        guard isRunning else { return }

        motionManager.stopAccelerometerUpdates()
        isRunning = false

        DispatchQueue.main.async {
            self.isUserMoving = false
            self.accelerationMagnitude = 1.0
        }

        AppLogger.run.info("Motion monitoring stopped")
    }

    // MARK: - Anti-Cheat Snapshot

    /// Returns true if the device shows physical movement consistent with running.
    /// Used by AntiCheatService to cross-validate GPS speed.
    var isPhysicallyActive: Bool {
        isUserMoving
    }
}
