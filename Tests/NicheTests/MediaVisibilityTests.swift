import Foundation
import NicheKit
import NowPlayingWire
import Testing
@testable import Niche

final class MediaRule {
    var visibility = MediaVisibility(pauseGrace: 5)

    func shows(_ media: NowPlaying?, fillsScreen: Bool = false, expanded: Bool = false, at now: Date) -> Bool {
        visibility.shows(media, fillsScreen: fillsScreen, expanded: expanded, at: now)
    }
}

struct MediaVisibilityTests {
    let start = Date(timeIntervalSince1970: 5000)
    let rule = MediaRule()

    @Test func pausedMediaLeavesAfterTheGrace() {
        _ = rule.shows(.sample(), at: start)

        #expect(rule.shows(.sample(playing: false), at: start + 1))
        #expect(rule.visibility.deadline == start + 6)
        #expect(rule.shows(.sample(playing: false), at: start + 5.9))
        #expect(!rule.shows(.sample(playing: false), at: start + 6))
        #expect(!rule.shows(.sample(playing: false), at: start + 7))
        #expect(rule.shows(.sample(), at: start + 8))
    }

    @Test func anOpenPanelHoldsPausedMediaAndTheGraceStartsWhenItCloses() {
        _ = rule.shows(.sample(), at: start)

        #expect(rule.shows(.sample(playing: false), expanded: true, at: start + 20))
        #expect(rule.visibility.deadline == nil)
        #expect(rule.shows(.sample(playing: false), at: start + 24))
        #expect(rule.visibility.deadline == start + 29)
        #expect(rule.shows(.sample(playing: false), at: start + 28.9))
        #expect(!rule.shows(.sample(playing: false), at: start + 29))
        #expect(!rule.shows(.sample(playing: false), expanded: true, at: start + 30))
    }

    @Test func anotherPlayersPausedMediaDoesNotTakeOver() {
        var other = NowPlaying.sample(playing: false)
        other.bundleIdentifier = "com.example.other"
        _ = rule.shows(.sample(), at: start)

        #expect(!rule.shows(other, at: start + 1))
        #expect(!rule.shows(.sample(playing: false), at: start + 2))
    }
}
