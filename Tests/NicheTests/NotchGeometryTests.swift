import Foundation
import Testing
@testable import Niche

struct NotchGeometryTests {
    let geometry = NotchGeometry(notch: CGRect(x: 750.5, y: 1074, width: 209, height: 38))

    @Test func theExpandedIslandIsTheNotchPlusApplesSideWidths() {
        #expect(geometry.expandedWidth == 453)
        #expect(geometry.expandedZone(height: 120) == CGRect(x: 855 - 236.5, y: 1112 - 120, width: 473, height: 120))
    }

    @Test func theHoveredZoneGrowsWithTheIsland() {
        let resting = geometry.mainZone(hovering: false, leading: 0, trailing: 0)
        let hovered = geometry.mainZone(hovering: true, leading: 0, trailing: 0)

        #expect(hovered.width > resting.width)
        #expect(hovered.minY < resting.minY)
        #expect(hovered.maxY == resting.maxY)
    }
}
