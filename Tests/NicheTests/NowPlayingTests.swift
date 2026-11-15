import Foundation
import NicheKit
@testable import NicheNowPlaying
import NowPlayingWire
import Testing
@testable import Niche

struct NowPlayingTests {
    @Test func theAppReadsTheLineTheHelperWrites() throws {
        let info: [String: Any] = [
            "kMRMediaRemoteNowPlayingInfoTitle": "A title",
            "kMRMediaRemoteNowPlayingInfoArtist": "An artist",
            "kMRMediaRemoteNowPlayingInfoDuration": NSNumber(value: 118),
            "kMRMediaRemoteNowPlayingInfoElapsedTime": NSNumber(value: 3),
            "kMRMediaRemoteNowPlayingInfoPlaybackRate": NSNumber(value: 1),
            "kMRMediaRemoteNowPlayingInfoTimestamp": Date(timeIntervalSince1970: 1000)
        ]
        let line = Snapshot.line(Snapshot.nowPlaying(
            info: info,
            bundleIdentifier: "com.example.player",
            name: "Player",
            pid: 41,
            playing: true,
            commands: [0, 1, 2, 3, 24],
            artwork: "/tmp/cover",
            now: Date()
        ))

        #expect(try JSONDecoder().decode(NowPlaying?.self, from: Data(line.utf8)) == .sample())
    }

    @Test func eachButtonSendsTheSystemsOwnCommand() {
        #expect(RemoteCommand(sending: .playPause)?.rawValue == 2)
        #expect(RemoteCommand(sending: .next)?.rawValue == 4)
        #expect(RemoteCommand(sending: .previous)?.rawValue == 5)
        #expect(RemoteCommand(sending: .seek) == nil)
        for command in [NowPlaying.Command.playPause, .next, .previous] {
            #expect(RemoteCommand(sending: command)?.command == command)
        }
    }
}
