import Foundation
import NicheKit
import NowPlayingWire
import Testing
@testable import Niche

extension NowPlaying {
    static func sample(
        playing: Bool = true,
        elapsed: Double = 3,
        timestamp: Double = 1000,
        duration: Double = 118,
        commands: Set<Command> = [.playPause, .seek],
        artwork: String? = "/tmp/cover"
    ) -> NowPlaying {
        NowPlaying(
            bundleIdentifier: "com.example.player",
            name: "Player",
            pid: 41,
            title: "A title",
            artist: "An artist",
            duration: duration,
            elapsed: elapsed,
            timestamp: timestamp,
            rate: playing ? 1 : 0,
            playing: playing,
            commands: commands,
            artwork: artwork
        )
    }
}

@MainActor
final class FakeNowPlaying: NowPlayingSource {
    var onChange: ((NowPlaying?) -> Void)?
    var started = false
    var sent: [String] = []

    func start() {
        started = true
    }

    func send(_ command: NowPlaying.Command, position: Double?) {
        sent.append(position.map { "\(command.rawValue) \($0)" } ?? command.rawValue)
    }
}
