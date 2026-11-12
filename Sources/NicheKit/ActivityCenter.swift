import Foundation
import Observation

@MainActor
@Observable
public final class ActivityCenter {
    public enum Transition: Sendable {
        case appear, change, reconfigure, disappear
    }

    public private(set) var activities: [LiveActivity] = []

    @ObservationIgnored public var onAlert: ((String, AlertConfiguration) -> Void)?
    @ObservationIgnored public var animate: (Transition, () -> Void) -> Void = { _, change in change() }
    @ObservationIgnored var onEvent: ((NotchEvent) -> Void)?

    @ObservationIgnored private var intentHandlers: [String: (String, Bool?, Double?) -> Void] = [:]
    @ObservationIgnored private var configurations: [String: JSONValue] = [:]
    @ObservationIgnored private var startTimers: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var staleTimers: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var dismissTimers: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var sequence = 0

    public init() {}

    public var presented: [LiveActivity] {
        activities.filter(\.isPresented).sorted {
            let (first, second) = ($0.content.relevanceScore ?? 0, $1.content.relevanceScore ?? 0)
            return first != second ? first > second : $0.sequence > $1.sequence
        }
    }

    public func configure(for type: String, dynamicIsland: JSONValue) throws {
        configurations[type] = dynamicIsland
        for index in activities.indices where activities[index].attributesType == type {
            var activity = activities[index]
            activity.template = dynamicIsland
            activity.island = try resolve(activity)
            animate(.reconfigure) { activities[index] = activity }
        }
    }

    @discardableResult
    public func request(
        id: String? = nil,
        attributesType: String? = nil,
        attributes: JSONValue? = nil,
        content: ActivityContent = ActivityContent(),
        dynamicIsland: JSONValue? = nil,
        alert: AlertConfiguration? = nil,
        start: Double? = nil
    ) throws -> String {
        guard let template = dynamicIsland ?? attributesType.flatMap({ configurations[$0] }) else {
            throw APIError(message: "request needs a dynamicIsland, or an attributesType that was configured first")
        }

        let now = Date().timeIntervalSince1970
        sequence += 1
        var activity = LiveActivity(
            id: id ?? UUID().uuidString,
            attributesType: attributesType,
            attributes: attributes ?? .object([:]),
            content: content,
            activityState: (start ?? now) > now ? .pending : state(for: content, at: now),
            island: DynamicIsland(),
            template: template,
            sequence: sequence,
            timestamp: now
        )
        activity.island = try resolve(activity)

        let id = activity.id
        cancelTimers(for: id)
        animate(.appear) {
            activities.removeAll { $0.id == id }
            activities.append(activity)
        }
        onEvent?(NotchEvent(event: .activityUpdate, id: id, activityState: activity.activityState, content: content))

        if activity.activityState == .pending, let start {
            startTimers[id] = timer(at: start) { [weak self] in self?.begin(id, alert: alert) }
        } else {
            scheduleStale(for: activity)
            if let alert { onAlert?(id, alert) }
        }
        return id
    }

    public func update(
        _ id: String,
        content: ActivityContent? = nil,
        dynamicIsland: JSONValue? = nil,
        alert: AlertConfiguration? = nil,
        timestamp: Double? = nil
    ) throws {
        guard let index = activities.firstIndex(where: { $0.id == id }) else {
            throw APIError(message: "no activity \"\(id)\"")
        }
        var activity = activities[index]
        guard activity.activityState != .ended else { throw APIError(message: "activity \"\(id)\" has ended") }
        if let timestamp {
            guard timestamp >= activity.timestamp else { return }
            activity.timestamp = timestamp
        }

        let previous = activity.activityState
        if let content { activity.content = content }
        if let dynamicIsland { activity.template = activity.template.mergingIsland(dynamicIsland) }
        if previous != .pending {
            activity.activityState = state(for: activity.content, at: Date().timeIntervalSince1970)
        }
        activity.island = try resolve(activity)

        animate(.change) { activities[index] = activity }
        if content != nil {
            onEvent?(NotchEvent(event: .contentUpdate, id: id, content: activity.content))
        }
        if activity.activityState != previous {
            onEvent?(NotchEvent(event: .activityStateUpdate, id: id, activityState: activity.activityState))
        }

        scheduleStale(for: activity)
        if let alert, previous != .pending { onAlert?(id, alert) }
    }

    public func end(
        _ id: String,
        content: ActivityContent? = nil,
        dismissalPolicy: DismissalPolicy = .default,
        timestamp: Double? = nil
    ) throws {
        guard let index = activities.firstIndex(where: { $0.id == id }) else {
            throw APIError(message: "no activity \"\(id)\"")
        }
        var activity = activities[index]
        if let content { activity.content = content }
        if let timestamp { activity.timestamp = max(timestamp, activity.timestamp) }
        activity.activityState = .ended
        activity.island = try resolve(activity)

        cancelTimers(for: id)
        animate(.change) { activities[index] = activity }
        if content != nil {
            onEvent?(NotchEvent(event: .contentUpdate, id: id, content: activity.content))
        }
        onEvent?(NotchEvent(event: .activityStateUpdate, id: id, activityState: .ended))

        let now = Date().timeIntervalSince1970
        if case .after(let date) = dismissalPolicy, date > now {
            dismissTimers[id] = timer(at: min(date, now + 4 * 3600)) { [weak self] in self?.dismiss(id) }
        } else {
            dismiss(id)
        }
    }

    public func onIntent(for id: String, _ handler: @escaping (String, Bool?, Double?) -> Void) {
        intentHandlers[id] = handler
    }

    public func intent(_ intent: String, from id: String, isOn: Bool? = nil, value: Double? = nil) {
        intentHandlers[id]?(intent, isOn, value)
        onEvent?(NotchEvent(event: .intent, id: id, intent: intent, isOn: isOn, value: value))
    }

    public func opened(_ url: String, from id: String) {
        onEvent?(NotchEvent(event: .openURL, id: id, url: url))
    }

    func snapshot() -> [ActivitySnapshot] {
        activities.map {
            ActivitySnapshot(
                id: $0.id,
                attributesType: $0.attributesType,
                attributes: $0.attributes,
                content: $0.content,
                activityState: $0.activityState
            )
        }
    }

    private func begin(_ id: String, alert: AlertConfiguration?) {
        guard let index = activities.firstIndex(where: { $0.id == id }) else { return }
        var activity = activities[index]
        activity.activityState = state(for: activity.content, at: Date().timeIntervalSince1970)
        activity.island = (try? resolve(activity)) ?? activity.island

        animate(.appear) { activities[index] = activity }
        onEvent?(NotchEvent(event: .activityStateUpdate, id: id, activityState: activity.activityState))
        scheduleStale(for: activity)
        if let alert { onAlert?(id, alert) }
    }

    private func dismiss(_ id: String) {
        guard activities.contains(where: { $0.id == id }) else { return }
        cancelTimers(for: id)
        animate(.disappear) {
            activities.removeAll { $0.id == id }
        }
        onEvent?(NotchEvent(event: .activityStateUpdate, id: id, activityState: .dismissed))
    }

    private func scheduleStale(for activity: LiveActivity) {
        let id = activity.id
        staleTimers.removeValue(forKey: id)?.cancel()
        guard activity.activityState == .active, let date = activity.content.staleDate else { return }

        staleTimers[id] = timer(at: date) { [weak self] in
            guard let self, let index = activities.firstIndex(where: { $0.id == id }) else { return }
            var activity = activities[index]
            guard activity.activityState == .active else { return }
            activity.activityState = .stale
            activity.island = (try? resolve(activity)) ?? activity.island
            animate(.change) { activities[index] = activity }
            onEvent?(NotchEvent(event: .activityStateUpdate, id: id, activityState: .stale))
        }
    }

    private func state(for content: ActivityContent, at now: Double) -> ActivityState {
        content.staleDate.map { $0 <= now } == true ? .stale : .active
    }

    private func resolve(_ activity: LiveActivity) throws -> DynamicIsland {
        let data = try JSONEncoder().encode(activity.template.resolved(with: activity.context))
        return try JSONDecoder().decode(DynamicIsland.self, from: data)
    }

    private func timer(at date: Double, _ action: @escaping @MainActor () -> Void) -> Task<Void, Never> {
        Task {
            try? await Task.sleep(for: .seconds(max(0, date - Date().timeIntervalSince1970)))
            guard !Task.isCancelled else { return }
            action()
        }
    }

    private func cancelTimers(for id: String) {
        startTimers.removeValue(forKey: id)?.cancel()
        staleTimers.removeValue(forKey: id)?.cancel()
        dismissTimers.removeValue(forKey: id)?.cancel()
    }
}
