import Foundation
import Network

@MainActor
final class ReachabilityMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "Wetterblatt.Reachability")

    var isConnected = true
    var onChange: ((Bool) -> Void)?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isConnected = connected
                self.onChange?(connected)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
