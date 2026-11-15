import CoreAudio
import Darwin

enum AudioOutput {
    private static let system = AudioObjectID(kAudioObjectSystemObject)

    static func onDefaultChange(_ handler: @escaping @MainActor () -> Void) {
        var address = address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(system, &address, .main) { _, _ in
            MainActor.assumeIsolated(handler)
        }
    }

    static let longestLatency: TimeInterval = 1

    static var latency: TimeInterval {
        var device = AudioObjectID(kAudioObjectUnknown)
        var rate: Float64 = 0
        guard read(system, kAudioHardwarePropertyDefaultOutputDevice, &device), device != kAudioObjectUnknown,
              read(device, kAudioDevicePropertyNominalSampleRate, &rate), rate > 0
        else { return 0 }

        var frames: UInt32 = 0
        var total: UInt32 = 0
        for (selector, scope) in [
            (kAudioDevicePropertyLatency, kAudioObjectPropertyScopeOutput),
            (kAudioDevicePropertySafetyOffset, kAudioObjectPropertyScopeOutput),
            (kAudioDevicePropertyBufferFrameSize, kAudioObjectPropertyScopeGlobal)
        ] where read(device, selector, &frames, scope: scope) {
            total += frames
        }
        return min(Double(total) / rate, longestLatency)
    }

    static func isPlaying(pid: pid_t, bundleIdentifier: String) -> Bool {
        guard let playing = playingProcesses else { return true }
        return plays(pid: pid, bundleIdentifier: bundleIdentifier, among: playing, responsible: responsible)
    }

    static func plays(
        pid: pid_t,
        bundleIdentifier: String,
        among playing: [(pid: pid_t, bundleIdentifier: String)],
        responsible: (pid_t) -> pid_t
    ) -> Bool {
        let owner = pid > 0 ? responsible(pid) : 0
        return playing.contains { process in
            process.bundleIdentifier == bundleIdentifier
                || process.bundleIdentifier.hasPrefix(bundleIdentifier + ".")
                || owner > 0 && (process.pid == pid || responsible(process.pid) == owner)
        }
    }

    private static var playingProcesses: [(pid: pid_t, bundleIdentifier: String)]? {
        guard #available(macOS 14.2, *) else { return nil }
        var address = address(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return nil }
        var processes = [AudioObjectID](repeating: kAudioObjectUnknown, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &processes) == noErr else { return nil }

        return processes.compactMap { process in
            var running: UInt32 = 0
            var pid: pid_t = 0
            var bundle: Unmanaged<CFString>?
            guard read(process, kAudioProcessPropertyIsRunningOutput, &running), running != 0,
                  read(process, kAudioProcessPropertyPID, &pid)
            else { return nil }
            let identifier = read(process, kAudioProcessPropertyBundleID, &bundle)
                ? bundle?.takeRetainedValue() as String? : nil
            return (pid, identifier ?? "")
        }
    }

    private static let responsible: @Sendable (pid_t) -> pid_t = {
        typealias Responsible = @convention(c) (pid_t) -> pid_t
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid")
        else { return { $0 } }
        let function = unsafeBitCast(symbol, to: Responsible.self)
        return { function($0) }
    }()

    static var defaultBluetoothAddress: String? {
        var device = AudioObjectID(kAudioObjectUnknown)
        guard read(system, kAudioHardwarePropertyDefaultOutputDevice, &device),
              device != kAudioObjectUnknown
        else { return nil }

        var transport: UInt32 = 0
        guard read(device, kAudioDevicePropertyTransportType, &transport),
              transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
        else { return nil }

        var uid: Unmanaged<CFString>?
        guard read(device, kAudioDevicePropertyDeviceUID, &uid),
              let uid = uid?.takeRetainedValue() as String?,
              uid.count >= 17
        else { return nil }

        return String(uid.prefix(17))
    }

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func read<Value>(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        _ value: inout Value,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> Bool {
        var address = address(selector)
        address.mScope = scope
        var size = UInt32(MemoryLayout<Value>.size)
        return withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0) == noErr
        }
    }
}
