import Foundation

public enum ActivityState: String, Codable, Sendable {
    case pending, active, ended, dismissed, stale
}

public struct ActivityContent: Codable, Equatable, Sendable {
    public var state: JSONValue?
    public var staleDate: Double?
    public var relevanceScore: Double?

    public init(state: JSONValue? = nil, staleDate: Double? = nil, relevanceScore: Double? = nil) {
        self.state = state
        self.staleDate = staleDate
        self.relevanceScore = relevanceScore
    }
}

public struct AlertConfiguration: Codable, Equatable, Sendable {
    public var title: String?
    public var body: String?
    public var sound: String?

    public init(title: String? = nil, body: String? = nil, sound: String? = nil) {
        self.title = title
        self.body = body
        self.sound = sound
    }
}

public enum DismissalPolicy: Codable, Equatable, Sendable {
    case `default`, immediate
    case after(Double)

    private enum Key: String, CodingKey {
        case after
    }

    public init(from decoder: Decoder) throws {
        if let object = try? decoder.container(keyedBy: Key.self) {
            self = .after(try object.decode(Double.self, forKey: .after))
            return
        }

        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "default": self = .default
        case "immediate": self = .immediate
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "dismissalPolicy is \"default\", \"immediate\" or {\"after\": unixSeconds}"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .default, .immediate:
            var container = encoder.singleValueContainer()
            try container.encode(self == .default ? "default" : "immediate")
        case .after(let date):
            var container = encoder.container(keyedBy: Key.self)
            try container.encode(date, forKey: .after)
        }
    }
}

public struct LiveActivity: Identifiable, Equatable, Sendable {
    public let id: String
    public internal(set) var attributesType: String?
    public internal(set) var attributes: JSONValue
    public internal(set) var content: ActivityContent
    public internal(set) var activityState: ActivityState
    public internal(set) var island: DynamicIsland
    var template: JSONValue
    var sequence: Int
    var timestamp: Double

    var context: JSONValue {
        [
            "activityID": .string(id),
            "attributes": attributes,
            "state": content.state ?? [:],
            "isStale": .bool(activityState == .stale)
        ]
    }

    var isPresented: Bool {
        activityState != .pending && activityState != .dismissed
    }
}
