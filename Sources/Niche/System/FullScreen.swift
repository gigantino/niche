import AppKit

@MainActor
enum FullScreen {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CopySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?

    private static let library: (connection: MainConnection, spaces: CopySpaces)? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW),
              let connection = dlsym(handle, "CGSMainConnectionID"),
              let spaces = dlsym(handle, "CGSCopyManagedDisplaySpaces")
        else { return nil }
        return (unsafeBitCast(connection, to: MainConnection.self), unsafeBitCast(spaces, to: CopySpaces.self))
    }()

    static func isOwned(by pid: pid_t, or bundleIdentifier: String, on screen: NSScreen?) -> Bool {
        guard let library,
              let displays = library.spaces(library.connection())?.takeRetainedValue() as? [[String: Any]]
        else { return false }

        let number = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        let display = number
            .flatMap { CGDisplayCreateUUIDFromDisplayID($0)?.takeRetainedValue() }
            .map { CFUUIDCreateString(nil, $0) as String }

        return owners(of: displays, display: display).contains {
            $0 == pid || NSRunningApplication(processIdentifier: $0)?.bundleIdentifier == bundleIdentifier
        }
    }

    static func owners(of displays: [[String: Any]], display: String?) -> [pid_t] {
        let shown = displays.first { $0["Display Identifier"] as? String == display } ?? displays.first
        guard let space = shown?["Current Space"] as? [String: Any], space["type"] as? Int == 4 else { return [] }

        let tiles = (space["TileLayoutManager"] as? [String: Any])?["TileSpaces"] as? [[String: Any]] ?? []
        return ([space] + tiles).compactMap { ($0["pid"] as? NSNumber)?.int32Value }
    }
}
