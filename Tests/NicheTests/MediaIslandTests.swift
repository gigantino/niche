import Foundation
import NicheKit
import NowPlayingWire
import Testing
@testable import Niche

struct MediaIslandTests {
    private func parts(_ media: NowPlaying, application: String? = nil) -> (island: DynamicIsland, details: [Node]) {
        let island = Media.island(for: media, start: 997, application: application)
        return (island, island.expanded?.bottom?.children?.last?.children ?? [])
    }

    @Test func playingMediaAnimatesAndCountsFromItsStart() {
        let (island, details) = parts(.sample())

        #expect(island.compactTrailing?.isActive == true)
        #expect(island.expanded?.trailing?.isActive == true)
        #expect(details[2].children?[1].systemImage == "pause.fill")
        #expect(details[4].type == .slider)
        #expect(details[4].timerInterval == [997, 1115])
        #expect(details[5].children?.first?.timerInterval == [997, 1115])
        #expect(details[4].value == nil)
        #expect(details[5].children?.last?.countsDown == true)
    }

    @Test func pausedMediaStandsStill() {
        let (island, details) = parts(.sample(playing: false))

        #expect(island.compactTrailing?.isActive == false)
        #expect(details[2].children?[1].systemImage == "play.fill")
        #expect(details[4].timerInterval == nil)
        #expect(details[4].value == 3)
        #expect(details[4].total == 118)
        #expect(details[5].children?.first?.text == "0:03")
        #expect(details[5].children?.last?.text == "1:55")
    }

    @Test func aCommandThePlayerLacksIsNotAButton() {
        let controls = parts(.sample()).details[2].children ?? []
        let all = parts(.sample(commands: [.playPause, .next, .previous, .seek])).details[2].children ?? []

        #expect(controls.map(\.type) == [.image, .button, .image])
        #expect(controls[0].opacity == 0.3)
        #expect(controls[1].intent == "playPause")
        #expect(all.map(\.intent) == ["previous", "playPause", "next"])
    }
}
