import Foundation

public enum SocketPath {
    public static var current: String {
        if let custom = ProcessInfo.processInfo.environment["NICHE_SOCKET"] { return custom }
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Niche/niche.sock")
            .path
    }
}
