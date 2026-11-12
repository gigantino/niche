import Foundation
import NicheKit
import Testing

@MainActor
struct ActivityCenterTests {
    let center = ActivityCenter()
    let label: JSONValue = ["compactLeading": ["type": "Text", "text": "{{state.label}}"]]
    var now: Double { Date().timeIntervalSince1970 }

    @Test func requestStartsAnActiveActivityAndFillsItsPlaceholders() throws {
        let id = try center.request(id: "a", content: ActivityContent(state: ["label": "one"]), dynamicIsland: label)

        #expect(id == "a")
        #expect(center.presented.map(\.id) == ["a"])
        #expect(center.presented[0].activityState == .active)
        #expect(center.presented[0].island.compactLeading?.text == "one")
    }

    @Test func requestWithoutAnIdGetsAUniqueOne() throws {
        let first = try center.request(dynamicIsland: label)
        let second = try center.request(dynamicIsland: label)

        #expect(first != second)
        #expect(center.presented.count == 2)
    }

    @Test func requestNeedsAnIslandOrAConfiguredType() throws {
        let error = #expect(throws: APIError.self) { try center.request(id: "a", attributesType: "Unknown") }
        #expect(error?.message == "request needs a dynamicIsland, or an attributesType that was configured first")

        try center.configure(for: "Delivery", dynamicIsland: label)
        try center.request(id: "a", attributesType: "Delivery", content: ActivityContent(state: ["label": "typed"]))
        #expect(center.presented[0].island.compactLeading?.text == "typed")
    }

    @Test func configureRerendersActivitiesOfThatType() throws {
        try center.configure(for: "Delivery", dynamicIsland: label)
        try center.request(id: "a", attributesType: "Delivery")
        try center.configure(for: "Delivery", dynamicIsland: ["minimal": ["type": "Spacer"]])

        #expect(center.presented[0].island.compactLeading == nil)
        #expect(center.presented[0].island.minimal?.type == .spacer)
    }

    @Test func aPlaceholderAloneKeepsTheValuesTypeAndEmbeddedOnesBecomeText() throws {
        try center.request(
            id: "a",
            attributes: ["kind": "demo"],
            content: ActivityContent(state: ["progress": 0.25, "minutes": 12, "on": true]),
            dynamicIsland: [
                "compactLeading": ["type": "ProgressView", "value": "{{state.progress}}"],
                "compactTrailing": ["type": "Text", "text": "{{state.minutes}} min, {{state.progress}} {{attributes.kind}}"],
                "minimal": ["type": "Text", "text": "[{{state.missing}}] {{activityID}}", "if": "{{state.on}}"]
            ]
        )
        let island = center.presented[0].island

        #expect(island.compactLeading?.value == 0.25)
        #expect(island.compactTrailing?.text == "12 min, 0.25 demo")
        #expect(island.minimal?.text == "[] a")
        #expect(island.minimal?.isVisible == true)
    }

    @Test func aBadViewIsRejectedAndLeavesTheActivityAsItWas() throws {
        try center.request(id: "a", content: ActivityContent(state: ["label": "kept"]), dynamicIsland: label)

        #expect(throws: DecodingError.self) {
            try center.update("a", dynamicIsland: ["minimal": ["type": "Bogus"]])
        }
        #expect(center.presented[0].island.compactLeading?.text == "kept")
        #expect(center.presented[0].island.minimal == nil)
    }

    @Test func updateReplacesTheContentAndMergesIslandParts() throws {
        try center.request(id: "a", content: ActivityContent(state: ["label": "one"]), dynamicIsland: [
            "compactLeading": ["type": "Text", "text": "{{state.label}}"],
            "expanded": ["center": ["type": "Text", "text": "center"]]
        ])
        try center.update(
            "a",
            content: ActivityContent(state: ["label": "two"]),
            dynamicIsland: ["widgetURL": "app://x", "expanded": ["bottom": ["type": "Spacer"]]]
        )
        let island = center.presented[0].island

        #expect(island.compactLeading?.text == "two")
        #expect(island.widgetURL == "app://x")
        #expect(island.expanded?.center?.text == "center")
        #expect(island.expanded?.bottom?.type == .spacer)
    }

    @Test func anUpdateOlderThanTheLastOneIsIgnored() throws {
        try center.request(id: "a", content: ActivityContent(state: ["label": "one"]), dynamicIsland: label)
        try center.update("a", content: ActivityContent(state: ["label": "newer"]), timestamp: now + 100)
        try center.update("a", content: ActivityContent(state: ["label": "older"]), timestamp: now - 100)

        #expect(center.presented[0].island.compactLeading?.text == "newer")
    }

    @Test func theMostRelevantActivityComesFirstThenTheMostRecent() throws {
        try center.request(id: "low", content: ActivityContent(relevanceScore: 1), dynamicIsland: label)
        try center.request(id: "high", content: ActivityContent(relevanceScore: 9), dynamicIsland: label)
        try center.request(id: "first", dynamicIsland: label)
        try center.request(id: "second", dynamicIsland: label)

        #expect(center.presented.map(\.id) == ["high", "low", "second", "first"])
    }

    @Test func aStaleDateInThePastMakesItStaleAndALaterOneMakesItActiveAgain() throws {
        let stale: JSONValue = ["compactLeading": ["type": "Text", "text": "stale", "if": "{{isStale}}"]]
        try center.request(id: "a", content: ActivityContent(staleDate: now - 1), dynamicIsland: stale)
        #expect(center.presented[0].activityState == .stale)
        #expect(center.presented[0].island.compactLeading?.isVisible == true)

        try center.update("a", content: ActivityContent())
        #expect(center.presented[0].activityState == .active)
        #expect(center.presented[0].island.compactLeading?.isVisible == false)
    }

    @Test func itBecomesStaleWhenTheStaleDatePasses() async throws {
        try center.request(id: "a", content: ActivityContent(staleDate: now + 0.1), dynamicIsland: label)
        #expect(center.presented[0].activityState == .active)

        try await Task.sleep(for: .milliseconds(400))
        #expect(center.presented[0].activityState == .stale)
    }

    @Test func aStartInTheFutureKeepsItPendingUntilThen() async throws {
        var alerts: [String] = []
        center.onAlert = { id, _ in alerts.append(id) }
        try center.request(id: "a", dynamicIsland: label, alert: AlertConfiguration(title: "Go"), start: now + 0.15)

        #expect(center.presented.isEmpty)
        #expect(center.activities.map(\.activityState) == [.pending])
        #expect(alerts.isEmpty)

        try await Task.sleep(for: .milliseconds(500))
        #expect(center.presented.map(\.activityState) == [.active])
        #expect(alerts == ["a"])
    }

    @Test func endRemovesItAtOnceByDefault() throws {
        try center.request(id: "a", dynamicIsland: label)
        try center.end("a")

        #expect(center.activities.isEmpty)
        #expect(throws: APIError.self) { try center.end("a") }
    }

    @Test func endWithALaterDismissalKeepsTheFinalContentUntilThen() async throws {
        try center.request(id: "a", content: ActivityContent(state: ["label": "one"]), dynamicIsland: label)
        try center.end("a", content: ActivityContent(state: ["label": "done"]), dismissalPolicy: .after(now + 0.15))

        #expect(center.presented.map(\.activityState) == [.ended])
        #expect(center.presented[0].island.compactLeading?.text == "done")
        let error = #expect(throws: APIError.self) { try center.update("a", content: ActivityContent()) }
        #expect(error?.message == "activity \"a\" has ended")

        try await Task.sleep(for: .milliseconds(500))
        #expect(center.activities.isEmpty)
    }

    @Test func requestingAnExistingIdReplacesIt() throws {
        try center.request(id: "a", content: ActivityContent(state: ["label": "one"]), dynamicIsland: label)
        try center.request(id: "a", content: ActivityContent(state: ["label": "two"]), dynamicIsland: label)

        #expect(center.presented.map(\.island.compactLeading?.text) == ["two"])
    }

    @Test func alertsAreDeliveredOnRequestAndUpdate() throws {
        var alerts: [String?] = []
        center.onAlert = { _, alert in alerts.append(alert.sound) }
        try center.request(id: "a", dynamicIsland: label, alert: AlertConfiguration(sound: "Pop"))
        try center.update("a", alert: AlertConfiguration(sound: "Ping"))

        #expect(alerts == ["Pop", "Ping"])
    }

    @Test func aBuiltInReceivesTheIntentsOfItsOwnActivity() {
        var received: [String] = []
        center.onIntent(for: "a") { intent, _, value in received.append("\(intent) \(value ?? 0)") }

        center.intent("seek", from: "a", value: 12)
        center.intent("seek", from: "b", value: 99)
        #expect(received == ["seek 12.0"])
    }

    @Test func changesGoThroughTheAnimationHook() throws {
        var transitions: [ActivityCenter.Transition] = []
        center.animate = { transition, change in
            transitions.append(transition)
            change()
        }
        try center.configure(for: "Type", dynamicIsland: label)
        try center.request(id: "a", attributesType: "Type")
        try center.update("a", content: ActivityContent())
        try center.configure(for: "Type", dynamicIsland: label)
        try center.end("a")

        #expect(transitions == [.appear, .change, .reconfigure, .change, .disappear])
    }
}
