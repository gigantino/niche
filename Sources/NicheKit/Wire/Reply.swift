import Foundation

public struct Reply: Encodable, Sendable {
    public var ok = true
    public var error: String?
    public var id: String?
    public var activities: [ActivitySnapshot]?
    public var areActivitiesEnabled: Bool?
    public var notch: [CGFloat]?
    public var version: String?
}

public struct ActivitySnapshot: Encodable, Sendable {
    public var id: String
    public var attributesType: String?
    public var attributes: JSONValue
    public var content: ActivityContent
    public var activityState: ActivityState
}

public struct NotchEvent: Encodable, Sendable {
    public enum Name: String, Encodable, CaseIterable, Sendable {
        case activityUpdate, contentUpdate, activityStateUpdate, intent, openURL
    }

    public var event: Name
    public var id: String?
    public var activityState: ActivityState?
    public var content: ActivityContent?
    public var intent: String?
    public var isOn: Bool?
    public var value: Double?
    public var url: String?
}

public struct APIError: Error, Sendable {
    public let message: String
}
