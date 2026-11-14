import Foundation
import Testing
@testable import Niche

struct AudioBandsTests {
    private func tone(_ frequency: Float, amplitude: Float = 0.25) -> [Float] {
        (0..<AudioBands.size).map { amplitude * sin(2 * .pi * frequency * Float($0) / 48000) }
    }

    private func decibels(_ frequency: Float) -> [Float] {
        AudioBands.decibels(of: tone(frequency), sampleRate: 48000)
    }

    @Test func eachBandReadsTheLevelTheReferenceAnalysisGives() {
        #expect(abs(decibels(47)[0] - 11.24) < 0.3)
        #expect(abs(decibels(120)[1] - 9.03) < 0.3)
        #expect(abs(decibels(300)[2] - 3.01) < 0.3)
        #expect(abs(decibels(1000)[3] - -0.26) < 0.3)
        #expect(abs(decibels(3000)[4] - -5.95) < 0.3)
        #expect(abs(decibels(8000)[5] - -8.33) < 0.3)
    }

    @Test func theHeightIsAStraightLineInDecibelsBetweenADotAndTheFullBar() {
        #expect(abs(AudioBands.bands[2].level(at: 0) - 0.71) < 0.001)
        #expect(abs(AudioBands.bands[2].level(at: -12) - 0.374) < 0.001)
        #expect(abs(AudioBands.bands[0].level(at: 10) - 0.66) < 0.001)
        #expect(AudioBands.bands[3].level(at: -150) == AudioBands.floor)
        #expect(AudioBands.bands[5].level(at: 60) == 1)
        #expect(AudioBands.bands[1].level(at: 0) < AudioBands.bands[2].level(at: 0))
    }
}
