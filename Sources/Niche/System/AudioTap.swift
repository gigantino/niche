import CoreAudio
import Foundation

final class AudioTap: Sendable {
    let sampleRate: Float

    private let tap: AudioObjectID
    private let device: AudioObjectID
    private let procedure: AudioDeviceIOProcID

    init?(receive: @escaping @Sendable ([Float]) -> Void) {
        guard #available(macOS 14.2, *) else { return nil }

        let description = CATapDescription(monoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.name = "Niche"
        description.isPrivate = true
        description.muteBehavior = .unmuted

        var tap = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateProcessTap(description, &tap) == noErr else { return nil }

        var format = AudioStreamBasicDescription()
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        AudioObjectGetPropertyData(tap, &address, 0, nil, &size, &format)

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Niche",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: description.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true
            ]]
        ]
        let queue = DispatchQueue(label: "ch.ggtn.niche.audio.io", qos: .userInteractive)
        var device = AudioObjectID(kAudioObjectUnknown)
        var procedure: AudioDeviceIOProcID?
        guard AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &device) == noErr,
              AudioDeviceCreateIOProcIDWithBlock(&procedure, device, queue, { _, input, _, _, _ in
                  let buffer = input.pointee.mBuffers
                  guard let data = buffer.mData, buffer.mDataByteSize > 0 else { return }
                  receive(Array(UnsafeBufferPointer(
                      start: data.assumingMemoryBound(to: Float.self),
                      count: Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                  )))
              }) == noErr,
              let procedure,
              AudioDeviceStart(device, procedure) == noErr
        else {
            if let procedure { AudioDeviceDestroyIOProcID(device, procedure) }
            if device != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(device) }
            AudioHardwareDestroyProcessTap(tap)
            return nil
        }

        self.tap = tap
        self.device = device
        self.procedure = procedure
        sampleRate = format.mSampleRate > 0 ? Float(format.mSampleRate) : 48000
    }

    deinit {
        AudioDeviceStop(device, procedure)
        AudioDeviceDestroyIOProcID(device, procedure)
        AudioHardwareDestroyAggregateDevice(device)
        if #available(macOS 14.2, *) { AudioHardwareDestroyProcessTap(tap) }
    }
}
