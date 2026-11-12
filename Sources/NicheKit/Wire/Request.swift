import Foundation

public struct Request: Codable, Equatable, Sendable {
    public enum Operation: String, CaseIterable, Sendable {
        case configure, request, update, end, activities, subscribe, info, haptic
    }

    public var op: String
    public var id: String?
    public var `for`: String?
    public var attributesType: String?
    public var attributes: JSONValue?
    public var content: ActivityContent?
    public var dynamicIsland: JSONValue?
    public var alertConfiguration: AlertConfiguration?
    public var dismissalPolicy: DismissalPolicy?
    public var start: Double?
    public var timestamp: Double?
    public var bound: Bool?
    public var strength: Int32?
}
