import NicheKit
import OSLog

@MainActor
final class AirPodsActivity: BuiltInActivity {
    static let id = "airpods"

    private let monitor = AirPodsMonitor()
    private var dismissal: Task<Void, Never>?
    private let log = Logger(subsystem: "ch.ggtn.niche", category: "airpods")

    func start(center: ActivityCenter) {
        monitor.onConnect = { [weak self] in self?.show($0, in: center) }
        monitor.onBatteryChange = { airPods in
            guard let island = try? JSONValue(encoding: airPods.island) else { return }
            try? center.update(Self.id, dynamicIsland: island)
        }
        monitor.start()
    }

    private func show(_ airPods: AirPods, in center: ActivityCenter) {
        do {
            try center.request(
                id: Self.id,
                attributesType: "AirPods",
                content: ActivityContent(relevanceScore: 100),
                dynamicIsland: JSONValue(encoding: airPods.island)
            )
        } catch {
            log.error("\(String(describing: error), privacy: .public)")
        }

        dismissal?.cancel()
        dismissal = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            try? center.end(Self.id, dismissalPolicy: .immediate)
        }
    }
}
