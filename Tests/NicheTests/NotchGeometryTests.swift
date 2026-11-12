import Foundation
import Testing
@testable import Niche

struct NotchGeometryTests {
    let geometry = NotchGeometry(notch: CGRect(x: 750.5, y: 1074, width: 209, height: 38))

    @Test func theExpandedIslandIsTheNotchPlusApplesSideWidths() {
        #expect(geometry.expandedWidth == 453)
        #expect(geometry.expandedZone(height: 120) == CGRect(x: 855 - 236.5, y: 1112 - 120, width: 473, height: 120))
    }

    @Test func thePanelHasRoomForTheTallestIslandAndItsShadow() {
        #expect(geometry.panelFrame == CGRect(x: 855 - 260.5, y: 1112 - 248, width: 521, height: 248))
    }

    @Test func theCompactZoneCoversTheNotchAndBothWings() {
        let zone = geometry.mainZone(hovering: false, leading: 30, trailing: 20)

        #expect(zone == CGRect(x: 855 - 129.5 - 5, y: 1073, width: 259, height: 40))
        #expect(zone.contains(CGPoint(x: 730, y: 1090)))
        #expect(!zone.contains(CGPoint(x: 710, y: 1090)))
    }

    @Test func theHoveredZoneGrowsWithTheIsland() {
        let resting = geometry.mainZone(hovering: false, leading: 0, trailing: 0)
        let hovered = geometry.mainZone(hovering: true, leading: 0, trailing: 0)

        #expect(hovered.width > resting.width)
        #expect(hovered.minY < resting.minY)
        #expect(hovered.maxY == resting.maxY)
    }

    @Test func theDetachedCircleSitsToTheRightOfTheNotch() {
        let circle = geometry.detachedZone

        #expect(circle.width == 34)
        #expect(circle.height == 34)
        #expect(circle.minX == 750.5 + 209 + 6 + 8)
        #expect(circle.midY == 1093)
    }
}
