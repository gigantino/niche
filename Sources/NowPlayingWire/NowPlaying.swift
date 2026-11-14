import Foundation

public struct NowPlaying: Codable, Equatable, Sendable {
    public enum Command: String, Codable, Sendable {
        case playPause, next, previous, seek
    }

    public var bundleIdentifier: String
    public var name: String
    public var pid: Int32
    public var title: String
    public var artist: String
    public var duration: Double
    public var elapsed: Double
    public var timestamp: Double
    public var rate: Double
    public var playing: Bool
    public var commands: Set<Command>
    public var artwork: String?

    public init(
        bundleIdentifier: String,
        name: String,
        pid: Int32,
        title: String,
        artist: String,
        duration: Double,
        elapsed: Double,
        timestamp: Double,
        rate: Double,
        playing: Bool,
        commands: Set<Command>,
        artwork: String?
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.pid = pid
        self.title = title
        self.artist = artist
        self.duration = duration
        self.elapsed = elapsed
        self.timestamp = timestamp
        self.rate = rate
        self.playing = playing
        self.commands = commands
        self.artwork = artwork
    }
}

public struct NowPlayingRequest: Codable, Equatable, Sendable {
    public var command: NowPlaying.Command
    public var position: Double?

    public init(command: NowPlaying.Command, position: Double? = nil) {
        self.command = command
        self.position = position
    }
}
