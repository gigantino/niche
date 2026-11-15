import Foundation
import Testing
@testable import Niche

struct AudioAnalyzerTests {
    private func tone(_ count: Int, frequency: Float = 440) -> [Float] {
        (0..<count).map { 0.25 * sin(2 * .pi * frequency * Float($0) / 48000) }
    }

    @Test func framesStartWithTheFirstSoundAndThenKeepComing() {
        var analyzer = AudioAnalyzer(sampleRate: 48000)
        let silence = [Float](repeating: 0, count: 4096)

        #expect(analyzer.add(silence).isEmpty)
        #expect(!analyzer.heard)
        #expect(analyzer.add(tone(2048)).count == 2)
        #expect(analyzer.heard)
        #expect(analyzer.add(silence).count == 4)
        #expect(analyzer.heard)
    }
}

struct LevelDelayTests {
    @Test func theBarsShowTheFrameThatIsDueAfterTheDelay() {
        var delay = LevelDelay()
        delay.add([1], at: 10.0)
        delay.add([2], at: 10.1)
        delay.add([3], at: 10.2)

        #expect(delay.values(at: 10.2, delay: 0) == [3])
        #expect(delay.values(at: 10.25, delay: 0.1) == [2])
        #expect(delay.values(at: 10.27, delay: 0.17) == [2])
        #expect(delay.values(at: 10.3, delay: 0.3) == [1])
    }
}

struct AudioMeterStateTests {
    @Test func theTapStopsOnlyForTheLastDepartureWhenNobodyListens() {
        var state = AudioMeterState()
        _ = state.attach()
        _ = state.attach()
        let one = state.detach()
        let whileOneListens = state.isIdle(since: one)
        let two = state.detach()

        #expect(!whileOneListens)
        #expect(!state.isIdle(since: one))
        #expect(state.isIdle(since: two))

        _ = state.attach()
        #expect(!state.isIdle(since: two))
        let three = state.detach()
        #expect(!state.isIdle(since: two))
        #expect(state.isIdle(since: three))
    }
}
