import Foundation
import NicheKit
import Testing
@testable import Niche

@MainActor
final class World {
    var pointer = CGPoint(x: 100, y: 100)
    var pressing = false
    var haptics = 0
    var sounds: [String?] = []
    var opened: [URL] = []

    var environment: NotchEnvironment {
        NotchEnvironment(
            pointerLocation: { self.pointer },
            isPressing: { self.pressing },
            haptic: { _ in self.haptics += 1 },
            playSound: { self.sounds.append($0) },
            open: { self.opened.append($0) }
        )
    }
}

@MainActor
struct NotchModelTests {
    static let notch = CGRect(x: 750.5, y: 1074, width: 209, height: 38)
    static let onNotch = CGPoint(x: 855, y: 1090)
    static let inPanel = CGPoint(x: 855, y: 1050)
    static let away = CGPoint(x: 100, y: 100)
    static let expandable: JSONValue = [
        "compactLeading": ["type": "Text", "text": "a"],
        "expanded": ["center": ["type": "Text", "text": "open"]]
    ]

    static let quick = NotchTiming(
        hoverEnter: 0.06,
        hoverLeave: 0.2,
        hold: 0.12,
        collapseGrace: 0.08,
        minimumOpen: 0.12,
        reopenLockout: 0.05,
        alert: 0.3,
        hapticGap: 0,
        poll: 0.01
    )

    let center = ActivityCenter()
    let world = World()
    let model: NotchModel

    init() {
        model = Self.model(center: center, world: world, timing: Self.quick)
    }

    private static func model(center: ActivityCenter, world: World, timing: NotchTiming) -> NotchModel {
        let model = NotchModel(center: center, environment: world.environment, timing: timing)
        model.geometry = NotchGeometry(notch: notch)
        return model
    }

    private func timed(_ change: (inout NotchTiming) -> Void) -> NotchModel {
        var timing = Self.quick
        change(&timing)
        return Self.model(center: center, world: world, timing: timing)
    }

    private func move(to point: CGPoint) {
        world.pointer = point
        model.pointerMoved(to: point)
    }

    private func pause(_ seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    @Test func hoverStartsAfterTheEnterDelayWithAHapticAndEndsAfterTheLeaveDelayWithout() async throws {
        move(to: Self.onNotch)
        #expect(!model.isHovering)

        try await pause(0.14)
        #expect(model.isHovering)
        #expect(world.haptics == 1)

        move(to: Self.away)
        try await pause(0.1)
        #expect(model.isHovering)

        try await pause(0.3)
        #expect(!model.isHovering)
        #expect(world.haptics == 1)
    }

    @Test func aPointerThatOnlyPassesOverDoesNotHover() async throws {
        let model = timed { $0.hoverEnter = 0.3 }
        world.pointer = Self.onNotch
        model.pointerMoved(to: Self.onNotch)
        try await pause(0.05)
        world.pointer = Self.away
        model.pointerMoved(to: Self.away)

        try await pause(0.5)
        #expect(!model.isHovering)
        #expect(world.haptics == 0)
    }

    @Test func oneActivityIsCompactWithItsMeasuredWings() throws {
        try center.request(id: "a", dynamicIsland: [
            "compactLeading": ["type": "Text", "text": "a"],
            "compactTrailing": ["type": "Text", "text": "b"]
        ])
        model.measured(52, edge: .leading)
        model.measured(24, edge: .trailing)

        #expect(model.primary?.id == "a")
        #expect(!model.isMinimal)
        #expect(model.detached == nil)
        #expect(model.wings.leading == 52)
        #expect(model.wings.trailing == 24)
    }

    @Test func aMissingCompactSideTakesNoWidth() throws {
        try center.request(id: "a", dynamicIsland: ["compactTrailing": ["type": "Text", "text": "b"]])
        model.measured(52, edge: .leading)
        model.measured(24, edge: .trailing)

        #expect(model.wings.leading == 0)
        #expect(model.wings.trailing == 24)
    }

    @Test func twoActivitiesShowTheMostRelevantAsMinimalAndTheNextDetached() throws {
        try center.request(id: "low", content: ActivityContent(relevanceScore: 1), dynamicIsland: Self.expandable)
        try center.request(id: "high", content: ActivityContent(relevanceScore: 9), dynamicIsland: Self.expandable)

        #expect(model.isMinimal)
        #expect(model.primary?.id == "high")
        #expect(model.detached?.id == "low")

        model.measured(80, edge: .leading)
        #expect(model.wings.leading == 45)
        #expect(model.wings.trailing == 0)

        model.measured(10, edge: .leading)
        #expect(model.wings.leading == 37)
    }

    @Test func aTapExpandsAnActivityThatHasNoWidgetURL() throws {
        try center.request(id: "a", dynamicIsland: Self.expandable)
        model.pointerPressed(at: Self.onNotch)
        model.pointerReleased(at: Self.onNotch)

        #expect(model.expanded?.id == "a")
        #expect(world.opened.isEmpty)
        model.collapse()
    }

    @Test func aTapOpensTheWidgetURLInstead() throws {
        var island = Self.expandable
        if case .object(var fields) = island {
            fields["widgetURL"] = "niche-test://order/12"
            island = .object(fields)
        }
        try center.request(id: "a", dynamicIsland: island)
        model.pointerPressed(at: Self.onNotch)
        model.pointerReleased(at: Self.onNotch)

        #expect(model.expanded == nil)
        #expect(world.opened == [URL(string: "niche-test://order/12")!])
    }

    @Test func aTapOnTheDetachedCircleTargetsTheSecondActivity() throws {
        try center.request(id: "low", content: ActivityContent(relevanceScore: 1), dynamicIsland: Self.expandable)
        try center.request(id: "high", content: ActivityContent(relevanceScore: 9), dynamicIsland: Self.expandable)
        let circle = try #require(model.geometry).detachedZone
        let point = CGPoint(x: circle.midX, y: circle.midY)

        model.pointerPressed(at: point)
        model.pointerReleased(at: point)
        #expect(model.expanded?.id == "low")
        model.collapse()
    }

    @Test func pressAndHoldExpandsWithAHaptic() async throws {
        try center.request(id: "a", dynamicIsland: Self.expandable)
        model.pointerPressed(at: Self.onNotch)
        #expect(model.expanded == nil)

        try await pause(0.35)
        #expect(model.expanded?.id == "a")
        #expect(world.haptics == 1)
        model.collapse()
    }

    @Test func anActivityWithoutExpandedRegionsDoesNotExpand() throws {
        try center.request(id: "a", dynamicIsland: ["compactLeading": ["type": "Text", "text": "a"]])
        model.pointerPressed(at: Self.onNotch)
        model.pointerReleased(at: Self.onNotch)

        #expect(model.expanded == nil)
    }

    @Test func theExpandedPanelClosesOnceThePointerHasLeft() async throws {
        try center.request(id: "a", dynamicIsland: Self.expandable)
        model.expand("a")
        world.pointer = Self.inPanel
        try await pause(0.1)
        #expect(model.expanded != nil)

        world.pointer = Self.away
        try await pause(0.5)
        #expect(model.expanded == nil)
        #expect(world.haptics == 1)
    }

    @Test func aBriefExitKeepsThePanelOpen() async throws {
        let model = timed { $0.collapseGrace = 0.4 }
        try center.request(id: "a", dynamicIsland: Self.expandable)
        model.expand("a")
        world.pointer = Self.inPanel
        try await pause(0.2)

        world.pointer = Self.away
        try await pause(0.1)
        world.pointer = Self.inPanel
        try await pause(0.6)
        #expect(model.expanded != nil)
        model.collapse()
    }

    @Test func thePanelStaysOpenForAMinimumTimeEvenIfThePointerLeavesAtOnce() async throws {
        let model = timed {
            $0.collapseGrace = 0.05
            $0.minimumOpen = 0.6
        }
        try center.request(id: "a", dynamicIsland: Self.expandable)
        model.expand("a")
        world.pointer = Self.inPanel
        try await pause(0.05)
        world.pointer = Self.away

        try await pause(0.25)
        #expect(model.expanded != nil)

        try await pause(0.7)
        #expect(model.expanded == nil)
    }

    @Test func aTapRightAfterClosingDoesNotReopenThePanel() async throws {
        let model = timed { $0.reopenLockout = 0.3 }
        try center.request(id: "a", dynamicIsland: Self.expandable)
        model.expand("a")
        model.pointerPressed(at: Self.away)
        model.pointerPressed(at: Self.onNotch)
        model.pointerReleased(at: Self.onNotch)
        #expect(model.expanded == nil)

        try await pause(0.45)
        model.pointerPressed(at: Self.onNotch)
        model.pointerReleased(at: Self.onNotch)
        #expect(model.expanded?.id == "a")
        model.collapse()
    }

    @Test func hapticsCloserTogetherThanTheGapAreDropped() async throws {
        let model = timed { $0.hapticGap = 0.3 }
        defer { model.collapse() }
        try center.request(id: "a", dynamicIsland: Self.expandable)
        try center.update("a", alert: AlertConfiguration(sound: "Pop"))
        try center.update("a", alert: AlertConfiguration(sound: "Pop"))
        #expect(world.haptics == 1)

        try await pause(0.45)
        try center.update("a", alert: AlertConfiguration(sound: "Pop"))
        #expect(world.haptics == 2)
        #expect(world.sounds.count == 3)
    }

    @Test func thePanelStaysOpenWhileAButtonIsHeld() async throws {
        try center.request(id: "a", dynamicIsland: Self.expandable)
        model.expand("a")
        world.pointer = Self.inPanel
        try await pause(0.1)

        world.pressing = true
        world.pointer = Self.away
        try await pause(0.4)
        #expect(model.expanded != nil)

        world.pressing = false
        try await pause(0.5)
        #expect(model.expanded == nil)
    }

    @Test func aPressOutsideTheExpandedPanelClosesIt() throws {
        try center.request(id: "a", dynamicIsland: Self.expandable)
        model.expand("a")
        model.pointerPressed(at: Self.away)

        #expect(model.expanded == nil)
    }

    @Test func anAlertExpandsPlaysItsSoundAndClosesByItself() async throws {
        try center.request(id: "a", dynamicIsland: Self.expandable)
        try center.update("a", alert: AlertConfiguration(title: "Ready", sound: "Pop"))

        #expect(model.expanded?.id == "a")
        #expect(world.sounds == ["Pop"])
        #expect(world.haptics == 1)

        try await pause(0.8)
        #expect(model.expanded == nil)
    }

    @Test func anAlertedPanelStaysWhileThePointerIsInside() async throws {
        try center.request(id: "a", dynamicIsland: Self.expandable)
        try center.update("a", alert: AlertConfiguration(title: "Ready"))
        world.pointer = Self.inPanel

        try await pause(0.8)
        #expect(model.expanded != nil)
        #expect(world.sounds == [nil])
        model.collapse()
    }

    @Test func endingTheExpandedActivityClosesThePanelAndReleasesThePointer() async throws {
        var captures: [Bool] = []
        model.onCaptureChange = { captures.append($0) }
        try center.request(id: "a", dynamicIsland: Self.expandable)
        model.expand("a")
        world.pointer = Self.inPanel
        try await pause(0.1)
        #expect(captures == [true])

        try center.end("a")
        #expect(model.expanded == nil)

        try await pause(0.1)
        #expect(captures == [true, false])
    }

    @Test func theExpandedSizeFollowsTheMeasuredHeightWithinApplesLimits() throws {
        try center.request(id: "a", dynamicIsland: Self.expandable)
        model.expand("a")

        model.measuredExpanded(height: 120)
        #expect(model.expandedSize == CGSize(width: 209 + 2 * 122, height: 120))

        model.measuredExpanded(height: 500)
        #expect(model.expandedSize?.height == 200)

        model.measuredExpanded(height: 10)
        #expect(model.expandedSize?.height == 84)
        model.collapse()
    }

    @Test func buttonsTogglesAndSlidersReportTheirIntentForTheirActivity() throws {
        var received: [String] = []
        center.onIntent(for: "a") { intent, isOn, value in
            received.append("\(intent) \(String(describing: isOn)) \(String(describing: value))")
        }
        center.onIntent(for: "b") { _, _, _ in received.append("wrong activity") }
        let actions = model.actions(for: "a")

        actions.intent("play", nil, nil)
        actions.intent("mute", true, nil)
        actions.intent("seek", nil, 43.5)
        #expect(received == ["play nil nil", "mute Optional(true) nil", "seek nil Optional(43.5)"])
    }

    @Test func aLinkOpensItsURLAndTellsSubscribers() async throws {
        let path = NSTemporaryDirectory() + "niche-" + UUID().uuidString.prefix(8) + "/s.sock"
        let server = Server(
            center: center,
            host: Server.Host(notch: { nil }, version: { nil }, haptic: { _ in }),
            path: path
        )
        try server.start()
        defer { server.stop() }
        for _ in 0..<200 where !FileManager.default.fileExists(atPath: path) {
            try await pause(0.01)
        }
        let client = try await Task.detached { try SocketClient(path: path, readTimeout: 5) }.value
        let subscribed = try await Task.detached {
            try client.write(Data(#"{"op":"subscribe"}"#.utf8))
            return client.read().map { String(decoding: $0, as: UTF8.self) }
        }.value
        #expect(subscribed == #"{"ok":true}"#)

        model.actions(for: "a").open("niche-test://link")
        let event = await Task.detached { client.read().map { String(decoding: $0, as: UTF8.self) } }.value

        #expect(world.opened == [URL(string: "niche-test://link")!])
        #expect(event == #"{"event":"openURL","id":"a","url":"niche-test://link"}"#)
    }
}
