import AppKit

struct NotchGeometry: Equatable {
    static let ear: CGFloat = 6
    static let hoverScale: CGFloat = 1.075
    static let margin: CGFloat = 24
    static let expandedEar: CGFloat = 10
    static let expandedSide: CGFloat = 122
    static let expandedMinHeight: CGFloat = 84
    static let expandedMaxHeight: CGFloat = 200
    static let expandedRadius: CGFloat = 44
    static let compactLimit: CGFloat = 72
    static let minimalWidth: ClosedRange<CGFloat> = 37...45
    static let detachedGap: CGFloat = 8

    let notch: CGRect

    init(notch: CGRect) {
        self.notch = notch
    }

    init?(screen: NSScreen) {
        guard screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea
        else { return nil }

        let height = screen.safeAreaInsets.top
        notch = CGRect(
            x: left.maxX,
            y: screen.frame.maxY - height,
            width: right.minX - left.maxX,
            height: height
        )
    }

    static var current: NotchGeometry? {
        NSScreen.screens.lazy.compactMap(NotchGeometry.init).first
    }

    var expandedWidth: CGFloat {
        notch.width + 2 * Self.expandedSide
    }

    var detachedDiameter: CGFloat {
        notch.height - 4
    }

    var detachedOffset: CGFloat {
        notch.width / 2 + Self.ear + Self.detachedGap + detachedDiameter / 2
    }

    var panelFrame: CGRect {
        topAnchored(
            width: expandedWidth + 2 * Self.expandedEar + 2 * Self.margin,
            height: Self.expandedMaxHeight + 2 * Self.margin
        )
    }

    func mainZone(hovering: Bool, leading: CGFloat, trailing: CGFloat) -> CGRect {
        let scale = hovering ? Self.hoverScale : 1
        let ears = hovering ? 2 * Self.ear : 0
        return topAnchored(
            width: (notch.width + leading + trailing + ears) * scale,
            height: notch.height * scale
        )
        .offsetBy(dx: (trailing - leading) / 2, dy: 0)
        .insetBy(dx: 0, dy: -1)
    }

    var detachedZone: CGRect {
        let diameter = detachedDiameter
        return CGRect(
            x: notch.midX + detachedOffset - diameter / 2,
            y: notch.midY - diameter / 2,
            width: diameter,
            height: diameter
        )
    }

    func expandedZone(height: CGFloat) -> CGRect {
        topAnchored(width: expandedWidth + 2 * Self.expandedEar, height: height)
    }

    private func topAnchored(width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: notch.midX - width / 2, y: notch.maxY - height, width: width, height: height)
    }
}
