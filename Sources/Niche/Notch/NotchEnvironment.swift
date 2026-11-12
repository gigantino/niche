import AppKit

@MainActor
struct NotchEnvironment {
    var pointerLocation: () -> CGPoint
    var isPressing: () -> Bool
    var haptic: (Int32) -> Void
    var playSound: (String?) -> Void
    var open: (URL) -> Void

    static var live: NotchEnvironment {
        let haptics = Haptics()
        return NotchEnvironment(
            pointerLocation: { NSEvent.mouseLocation },
            isPressing: { NSEvent.pressedMouseButtons & 1 != 0 },
            haptic: { haptics.tap(strength: $0) },
            playSound: { name in
                switch name {
                case nil, "default": NSSound.beep()
                case let name?: NSSound(named: name)?.play()
                }
            },
            open: { NSWorkspace.shared.open($0) }
        )
    }
}

struct NotchTiming: Equatable {
    var hoverEnter = 0.05
    var hoverLeave = 0.16
    var hold = 0.45
    var collapseGrace = 0.35
    var minimumOpen = 0.6
    var reopenLockout = 0.25
    var alert = 4.0
    var hapticGap = 0.12
    var poll = 0.05
}
