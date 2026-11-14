import NicheKit
import SwiftUI
import Testing
@testable import Niche

struct TuningTests {
    @Test func thePointerDelaysAreTheOnesTheOwnerTuned() {
        #expect(NotchTiming() == NotchTiming(
            hoverEnter: 0.05,
            hoverLeave: 0.16,
            hold: 0.45,
            collapseGrace: 0.35,
            minimumOpen: 0.6,
            reopenLockout: 0.25,
            alert: 4,
            hapticGap: 0.12,
            poll: 0.05
        ))
    }

    @Test func theBarsUseTheValuesFittedToTheIPhoneRecording() {
        #expect(AudioBands.bands.map(\.low) == [20, 71, 202, 640, 1613, 5120])
        #expect(AudioBands.bands.map(\.high) == [57, 180, 570, 1437, 4561, 10240])
        #expect(AudioBands.bands.map(\.offset) == [0.22, 0.30, 0.71, 0.87, 1.13, 1.26])
        #expect(AudioBands.bands.map(\.slope) == [0.044, 0.012, 0.028, 0.024, 0.027, 0.031])
        #expect(AudioBands.size == 2048)
        #expect(AudioBands.hop == 1024)
        #expect(AudioBands.floor == Float(3) / 42)
        #expect(AudioLevels.smoothing == 0.65)
        #expect(AudioBarsNode.gap == 0.9)
        #expect(AudioBands.audible == -120)
        #expect(AudioMeter.grace == 2)
        #expect(AudioMeterState.latencyInterval == 1)
    }

    @Test func eachLifecycleChangeHasItsAnimation() {
        #expect(ActivityCenter.Transition.appear.animation == .notch(stiffness: 150, damping: 20))
        #expect(ActivityCenter.Transition.change.animation == .easeOut(duration: 0.4))
        #expect(ActivityCenter.Transition.reconfigure.animation == .easeOut(duration: 0.3))
        #expect(ActivityCenter.Transition.disappear.animation == .notch(stiffness: 150, damping: 16))
    }

    @Test func theIslandSpringIsOneANewTargetCanRedirect() {
        #expect(Animation.notch(stiffness: 170, damping: 21) == .spring(
            response: 2 * .pi / 170.0.squareRoot(),
            dampingFraction: 21 / (2 * 170.0.squareRoot())
        ))
    }
}
