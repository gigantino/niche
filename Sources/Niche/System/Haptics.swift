import AppKit
import IOKit

@MainActor
final class Haptics {
    private typealias Create = @convention(c) (UInt64) -> Unmanaged<CFTypeRef>?
    private typealias Open = @convention(c) (CFTypeRef) -> IOReturn
    private typealias Close = @convention(c) (CFTypeRef) -> IOReturn
    private typealias Actuate = @convention(c) (CFTypeRef, Int32, UInt32, Float, Float) -> IOReturn

    private struct Library {
        let create: Create
        let open: Open
        let close: Close
        let actuate: Actuate

        init?() {
            guard let handle = dlopen(
                "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
                RTLD_NOW
            ),
                let create = dlsym(handle, "MTActuatorCreateFromDeviceID"),
                let open = dlsym(handle, "MTActuatorOpen"),
                let close = dlsym(handle, "MTActuatorClose"),
                let actuate = dlsym(handle, "MTActuatorActuate")
            else { return nil }

            self.create = unsafeBitCast(create, to: Create.self)
            self.open = unsafeBitCast(open, to: Open.self)
            self.close = unsafeBitCast(close, to: Close.self)
            self.actuate = unsafeBitCast(actuate, to: Actuate.self)
        }
    }

    private let library = Library()
    private var actuator: CFTypeRef?

    func tap(strength: Int32 = 6) {
        if actuate(strength) { return }
        close()
        if actuate(strength) { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    private func actuate(_ strength: Int32) -> Bool {
        guard let library, let actuator = actuator ?? open() else { return false }
        return library.actuate(actuator, strength, 0, 0, 0) == kIOReturnSuccess
    }

    private func open() -> CFTypeRef? {
        guard let library,
              let id = Self.trackpadID(),
              let created = library.create(id)?.takeRetainedValue(),
              library.open(created) == kIOReturnSuccess
        else { return nil }
        actuator = created
        return created
    }

    private func close() {
        if let library, let actuator {
            _ = library.close(actuator)
        }
        actuator = nil
    }

    private static func trackpadID() -> UInt64? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleMultitouchDevice"),
            &iterator
        ) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            let supported = IORegistryEntryCreateCFProperty(
                service, "ActuationSupported" as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? Bool
            let id = IORegistryEntryCreateCFProperty(
                service, "Multitouch ID" as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? UInt64
            if supported == true, let id { return id }
        }
        return nil
    }
}
