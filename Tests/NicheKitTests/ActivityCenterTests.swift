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

    @Test func theMostRelevantActivityComesFirstThenTheMostRecent() throws {
        try center.request(id: "low", content: ActivityContent(relevanceScore: 1), dynamicIsland: label)
        try center.request(id: "high", content: ActivityContent(relevanceScore: 9), dynamicIsland: label)
        try center.request(id: "first", dynamicIsland: label)
        try center.request(id: "second", dynamicIsland: label)

        #expect(center.presented.map(\.id) == ["high", "low", "second", "first"])
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

    @Test func aBuiltInReceivesTheIntentsOfItsOwnActivity() {
        var received: [String] = []
        center.onIntent(for: "a") { intent, _, value in received.append("\(intent) \(value ?? 0)") }

        center.intent("seek", from: "a", value: 12)
        center.intent("seek", from: "b", value: 99)
        #expect(received == ["seek 12.0"])
    }
}
