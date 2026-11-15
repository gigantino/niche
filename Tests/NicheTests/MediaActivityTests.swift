import Foundation
import NicheKit
import NowPlayingWire
import Testing
@testable import Niche

@MainActor
struct MediaActivityTests {
    let center = ActivityCenter()
    let world = World()
    let source = FakeNowPlaying()
    let model: NotchModel
    let activity: MediaActivity
    let screen = Screen()

    @MainActor
    final class Screen {
        var filled = false
        var playsHere = true
    }

    init() {
        model = NotchModel(center: center, environment: world.environment, timing: NotchModelTests.quick)
        model.geometry = NotchGeometry(notch: NotchModelTests.notch)
        activity = MediaActivity(
            source: source,
            fillsScreen: { [screen] _ in screen.filled },
            playsHere: { [screen] _ in screen.playsHere },
            visibility: MediaVisibility(pauseGrace: 0.15)
        )
        activity.start(center: center, notch: model)
    }

    private var shown: LiveActivity? {
        center.presented.first { $0.id == MediaActivity.id }
    }

    private func now(playing: Bool = true, elapsed: Double = 3, shift: Double = 0) -> NowPlaying {
        .sample(playing: playing, elapsed: elapsed, timestamp: Date().timeIntervalSince1970 + shift)
    }

    @Test func playingMediaBecomesAnActivity() {
        #expect(source.started)
        #expect(shown == nil)

        source.onChange?(now())

        #expect(shown?.attributesType == "Media")
        #expect(shown?.island.compactTrailing?.isActive == true)
        #expect(shown?.island.hasExpanded == true)
    }

    @Test func pausedMediaLeavesAfterTheGrace() async throws {
        source.onChange?(now())
        try await Task.sleep(for: .seconds(0.3))
        source.onChange?(now(playing: false))

        #expect(shown?.island.compactTrailing?.isActive == false)
        try await Task.sleep(for: .seconds(0.4))
        #expect(shown == nil)

        source.onChange?(now())
        #expect(shown != nil)
    }

    @Test func mediaHidesWhileItsPlayerFillsTheScreen() {
        source.onChange?(now())
        screen.filled = true
        activity.refresh()
        #expect(shown == nil)

        screen.filled = false
        activity.refresh()
        #expect(shown != nil)
    }

    @Test func mediaPlayingOnAnotherDeviceStaysAway() {
        screen.playsHere = false
        source.onChange?(now())
        #expect(shown == nil)

        screen.playsHere = true
        activity.refresh()
        #expect(shown?.island.compactTrailing?.isActive == true)
    }

    @Test func theButtonsReachThePlayer() {
        source.onChange?(now())

        center.intent("playPause", from: MediaActivity.id)
        center.intent("next", from: MediaActivity.id)
        center.intent("previous", from: MediaActivity.id)
        center.intent("seek", from: MediaActivity.id, value: 42)

        #expect(source.sent == ["playPause", "next", "previous", "seek 42.0"])
    }
}
