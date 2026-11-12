import Foundation

public struct Node: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case text = "Text"
        case image = "Image"
        case label = "Label"
        case progressView = "ProgressView"
        case slider = "Slider"
        case hStack = "HStack"
        case vStack = "VStack"
        case zStack = "ZStack"
        case spacer = "Spacer"
        case button = "Button"
        case toggle = "Toggle"
        case link = "Link"
        case video = "Video"
        case webView = "WebView"
        case audioBars = "AudioBars"
    }

    public var type: Kind

    public var text: String?
    public var date: Double?
    public var style: String?
    public var timerInterval: [Double]?
    public var countsDown: Bool?

    public var systemName: String?
    public var source: String?
    public var app: String?
    public var contentMode: String?
    public var title: String?
    public var systemImage: String?

    public var value: Double?
    public var total: Double?
    public var progressViewStyle: String?
    public var tint: String?
    public var buttonStyle: String?
    public var isActive: Bool?
    public var html: String?

    public var intent: String?
    public var isOn: Bool?
    public var destination: String?

    public var children: [Node]?
    public var spacing: CGFloat?
    public var alignment: String?
    public var minLength: CGFloat?

    public var font: FontSpec?
    public var foregroundStyle: String?
    public var lineLimit: Int?
    public var monospacedDigit: Bool?
    public var symbolEffect: String?
    public var frame: Frame?
    public var padding: Insets?
    public var background: String?
    public var cornerRadius: CGFloat?
    public var opacity: Double?
    public var blur: CGFloat?
    public var scaleEffect: CGFloat?
    public var tracking: CGFloat?
    public var layoutPriority: Double?

    public var `if`: Bool?
    public var unless: Bool?

    public var priority: Double?
    public var verticalPlacement: String?
    public var contentMargins: Insets?

    public var isVisible: Bool {
        `if` != false && unless != true
    }

    public init(_ type: Kind, _ configure: (inout Node) -> Void = { _ in }) {
        self.type = type
        configure(&self)
    }
}

public struct FontSpec: Codable, Equatable, Sendable {
    public var style: String?
    public var size: CGFloat?
    public var weight: String?
    public var design: String?

    private enum Key: String, CodingKey {
        case style, size, weight, design
    }

    public init(style: String? = nil, size: CGFloat? = nil, weight: String? = nil, design: String? = nil) {
        self.style = style
        self.size = size
        self.weight = weight
        self.design = design
    }

    public init(from decoder: Decoder) throws {
        if let style = try? decoder.singleValueContainer().decode(String.self) {
            self.init(style: style)
            return
        }
        let container = try decoder.container(keyedBy: Key.self)
        self.init(
            style: try container.decodeIfPresent(String.self, forKey: .style),
            size: try container.decodeIfPresent(CGFloat.self, forKey: .size),
            weight: try container.decodeIfPresent(String.self, forKey: .weight),
            design: try container.decodeIfPresent(String.self, forKey: .design)
        )
    }
}

public struct Frame: Codable, Equatable, Sendable {
    public var width: CGFloat?
    public var height: CGFloat?
    public var maxWidth: Length?
    public var maxHeight: Length?
    public var alignment: String?

    public init(
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        maxWidth: Length? = nil,
        maxHeight: Length? = nil,
        alignment: String? = nil
    ) {
        self.width = width
        self.height = height
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.alignment = alignment
    }
}

public enum Length: Codable, Equatable, Sendable {
    case infinity
    case points(CGFloat)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let points = try? container.decode(CGFloat.self) {
            self = .points(points)
        } else if try container.decode(String.self) == "infinity" {
            self = .infinity
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "expected a number or \"infinity\"")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .infinity: try container.encode("infinity")
        case .points(let points): try container.encode(points)
        }
    }

    public var value: CGFloat {
        switch self {
        case .infinity: .infinity
        case .points(let points): points
        }
    }
}

public struct Insets: Codable, Equatable, Sendable {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat

    public init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let all = try? container.decode(CGFloat.self) {
            self.init(top: all, leading: all, bottom: all, trailing: all)
            return
        }

        let values = try container.decode([CGFloat].self)
        switch values.count {
        case 2: self.init(top: values[1], leading: values[0], bottom: values[1], trailing: values[0])
        case 4: self.init(top: values[0], leading: values[1], bottom: values[2], trailing: values[3])
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "expected a number, [horizontal, vertical] or [top, leading, bottom, trailing]"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode([top, leading, bottom, trailing])
    }

    mutating func set(_ length: CGFloat, edges: String?) {
        switch edges ?? "all" {
        case "top": top = length
        case "bottom": bottom = length
        case "leading": leading = length
        case "trailing": trailing = length
        case "horizontal": (leading, trailing) = (length, length)
        case "vertical": (top, bottom) = (length, length)
        default: self = Insets(top: length, leading: length, bottom: length, trailing: length)
        }
    }
}
