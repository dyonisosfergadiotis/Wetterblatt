import CoreGraphics
import CoreMotion
import Foundation
import Observation
import UIKit

private enum HeroTiltMetrics {
    static let maxRoll: Double = 0.42
    static let maxPitch: Double = 0.34
    static let horizontalTravel: CGFloat = 12
    static let verticalTravel: CGFloat = 9
    static let smoothing: CGFloat = 0.14
    static let updateInterval: TimeInterval = 1.0 / 15.0
    static let minimumDelta: CGFloat = 0.2
}

@MainActor
@Observable
final class HeroTiltController {
    private let motionManager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "HeroTiltController.motion"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    var offset: CGSize = .zero

    func start() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            offset = .zero
            return
        }

        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else {
            offset = .zero
            return
        }

        guard motionManager.isDeviceMotionAvailable else {
            offset = .zero
            return
        }

        guard !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = HeroTiltMetrics.updateInterval
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] motion, _ in
            guard let motion else { return }

            let roll = min(max(motion.attitude.roll / HeroTiltMetrics.maxRoll, -1), 1)
            let pitch = min(max(motion.attitude.pitch / HeroTiltMetrics.maxPitch, -1), 1)
            let target = CGSize(
                width: CGFloat(roll) * HeroTiltMetrics.horizontalTravel,
                height: CGFloat(-pitch) * HeroTiltMetrics.verticalTravel
            )

            Task { @MainActor in
                guard let self else { return }
                let nextOffset = CGSize(
                    width: self.offset.width + (target.width - self.offset.width) * HeroTiltMetrics.smoothing,
                    height: self.offset.height + (target.height - self.offset.height) * HeroTiltMetrics.smoothing
                )

                guard abs(nextOffset.width - self.offset.width) > HeroTiltMetrics.minimumDelta
                    || abs(nextOffset.height - self.offset.height) > HeroTiltMetrics.minimumDelta
                else {
                    return
                }

                self.offset = nextOffset
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        offset = .zero
    }
}
