import Foundation

@MainActor
final class WeatherClock {
    private var timer: Timer?

    var now = Date()
    var onTick: ((Date) -> Void)?

    func start() {
        guard timer == nil else { return }
        tick()

        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        timer?.tolerance = 3
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        now = Date()
        onTick?(now)
    }

    deinit {
        timer?.invalidate()
    }
}
