import Foundation

public enum DynamicIslandMode: String, CaseIterable, Sendable {
    case expanded, compactLeading, compactTrailing, minimal
}

public struct DynamicIsland: Codable, Equatable, Sendable {
    public struct Expanded: Codable, Equatable, Sendable {
        public var leading: Node?
        public var trailing: Node?
        public var center: Node?
        public var bottom: Node?

        public init(leading: Node? = nil, trailing: Node? = nil, center: Node? = nil, bottom: Node? = nil) {
            self.leading = leading
            self.trailing = trailing
            self.center = center
            self.bottom = bottom
        }
    }

    public struct ContentMargins: Codable, Equatable, Sendable {
        public var edges: String?
        public var length: CGFloat
        public var `for`: String

        public init(edges: String? = nil, length: CGFloat, for mode: DynamicIslandMode) {
            self.edges = edges
            self.length = length
            self.for = mode.rawValue
        }
    }

    public var expanded: Expanded?
    public var compactLeading: Node?
    public var compactTrailing: Node?
    public var minimal: Node?
    public var widgetURL: String?
    public var contentMargins: [ContentMargins]?

    public init(
        expanded: Expanded? = nil,
        compactLeading: Node? = nil,
        compactTrailing: Node? = nil,
        minimal: Node? = nil,
        widgetURL: String? = nil,
        contentMargins: [ContentMargins]? = nil
    ) {
        self.expanded = expanded
        self.compactLeading = compactLeading
        self.compactTrailing = compactTrailing
        self.minimal = minimal
        self.widgetURL = widgetURL
        self.contentMargins = contentMargins
    }

    public var attached: Node? {
        minimal ?? compactLeading ?? compactTrailing
    }

    public var hasExpanded: Bool {
        guard let expanded else { return false }
        return expanded.leading != nil || expanded.trailing != nil || expanded.center != nil || expanded.bottom != nil
    }

    public func margins(for mode: DynamicIslandMode, default insets: Insets) -> Insets {
        (contentMargins ?? [])
            .filter { $0.for == mode.rawValue }
            .reduce(into: insets) { $0.set($1.length, edges: $1.edges) }
    }
}
