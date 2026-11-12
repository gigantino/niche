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
