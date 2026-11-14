import Foundation
import NicheKit
import Testing
@testable import Niche

@MainActor
struct FullScreenTests {
    static let desktop: [String: Any] = ["type": 0, "ManagedSpaceID": 1, "pid": 7]
    static let video: [String: Any] = [
        "type": 4,
        "pid": 41,
        "TileLayoutManager": ["TileSpaces": [["pid": 41], ["pid": 42]]]
    ]

    @Test func onlyTheDisplayWithTheNotchCounts() {
        let displays = [
            ["Display Identifier": "A", "Current Space": Self.desktop],
            ["Display Identifier": "B", "Current Space": Self.video]
        ]

        #expect(FullScreen.owners(of: displays, display: "A") == [])
        #expect(Set(FullScreen.owners(of: displays, display: "B")) == [41, 42])
        #expect(FullScreen.owners(of: displays, display: "unknown") == [])
    }
}
