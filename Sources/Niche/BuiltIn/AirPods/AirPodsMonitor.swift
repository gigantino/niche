import IOBluetooth
import OSLog

@MainActor
final class AirPodsMonitor: NSObject {
    var onConnect: ((AirPods) -> Void)?
    var onBatteryChange: ((AirPods) -> Void)?

    private var registration: IOBluetoothUserNotification?
    private var batteryLookup: Task<Void, Never>?
    private var lastConnect: (id: String, date: Date)?
    private var outputAddress: String?
    private let log = Logger(subsystem: "ch.ggtn.niche", category: "airpods")

    func start() {
        guard registration == nil else { return }
        registration = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(connected(_:device:))
        )

        outputAddress = AudioOutput.defaultBluetoothAddress
        AudioOutput.onDefaultChange { [weak self] in self?.outputChanged() }
    }

    @objc private nonisolated func connected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let address = device.addressString else { return }
        Task { @MainActor in
            guard let device = IOBluetoothDevice(addressString: address) else { return }
            announce(device, trigger: "bluetooth connect")
        }
    }

    private func outputChanged() {
        let address = AudioOutput.defaultBluetoothAddress
        log.notice("default output changed, bluetooth: \(address != nil, privacy: .public)")
        guard address != outputAddress else { return }
        outputAddress = address
        if let address, let device = IOBluetoothDevice(addressString: address) {
            announce(device, trigger: "audio output")
        }
    }

    private func announce(_ device: IOBluetoothDevice, trigger: String) {
        guard var airPods = AirPods(device: device) else { return }

        let now = Date()
        if let lastConnect, lastConnect.id == airPods.id, now.timeIntervalSince(lastConnect.date) < 8 {
            log.notice("\(trigger, privacy: .public): skipped, shown moments ago")
            return
        }
        lastConnect = (airPods.id, now)
        log.notice("\(trigger, privacy: .public): showing, battery \(airPods.battery ?? -1, privacy: .public)")
        onConnect?(airPods)

        batteryLookup?.cancel()
        guard airPods.battery == nil else { return }
        batteryLookup = Task {
            for wait in [0.4, 0.5, 0.7, 1.0] {
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }
                if let battery = AirPods.battery(of: device) {
                    airPods.battery = battery
                    onBatteryChange?(airPods)
                    return
                }
            }
        }
    }
}
