import CoreAudio

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
