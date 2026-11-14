import Foundation
import NowPlayingWire

public enum Snapshot {
    public static func nowPlaying(
        info: [String: Any],
        bundleIdentifier: String?,
        name: String?,
        pid: Int,
        playing: Bool,
        commands: [Int],
        artwork: String?,
        now: Date
    ) -> NowPlaying? {
        guard let bundleIdentifier, let title = text(info, "Title"), !title.isEmpty else { return nil }

        let rate = number(info, "PlaybackRate") ?? 0
        return NowPlaying(
            bundleIdentifier: bundleIdentifier,
            name: name ?? bundleIdentifier,
            pid: Int32(exactly: pid) ?? 0,
            title: title,
            artist: text(info, "Artist") ?? "",
            duration: number(info, "Duration") ?? 0,
            elapsed: number(info, "ElapsedTime") ?? 0,
            timestamp: ((info[key("Timestamp")] as? Date) ?? now).timeIntervalSince1970,
            rate: playing && rate == 0 ? 1 : rate,
            playing: playing,
            commands: Set(commands.compactMap { UInt32(exactly: $0).flatMap(RemoteCommand.init)?.command }),
            artwork: artwork
        )
    }

    public static func line(_ nowPlaying: NowPlaying?) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return nowPlaying.flatMap { try? encoder.encode($0) }.map { String(decoding: $0, as: UTF8.self) } ?? "null"
    }

    public static func artworkKey(_ info: [String: Any]) -> String {
        text(info, "ArtworkIdentifier")
            ?? [text(info, "Title"), text(info, "Artist"), text(info, "Album")].map { $0 ?? "" }.joined(separator: "\n")
    }

    static func key(_ name: String) -> String {
        "kMRMediaRemoteNowPlayingInfo" + name
    }

    private static func text(_ info: [String: Any], _ name: String) -> String? {
        info[key(name)] as? String
    }

    private static func number(_ info: [String: Any], _ name: String) -> Double? {
        (info[key(name)] as? NSNumber).map(\.doubleValue).flatMap { $0.isFinite ? $0 : nil }
    }
}
