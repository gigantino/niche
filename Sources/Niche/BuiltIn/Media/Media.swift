import Foundation
import NicheKit
import NowPlayingWire

enum Media {
    static let cover: CGFloat = 112

    static func island(
        for media: NowPlaying,
        start: Double,
        application: String?
    ) -> DynamicIsland {
        let interval = media.playing && media.duration > 0 ? [start, start + media.duration] : nil
        var bottom = stack(.hStack, spacing: 16, [
            opening(application, artwork(media, side: cover, radius: 14)),
            details(media, interval)
        ])
        bottom.padding = Insets(top: 4)

        return DynamicIsland(
            expanded: DynamicIsland.Expanded(
                leading: player(media),
                trailing: bars(media, width: 25, height: 28),
                bottom: bottom
            ),
            compactLeading: artwork(media, side: 24, radius: 6),
            compactTrailing: bars(media, width: 18, height: 20),
            minimal: artwork(media, side: 24, radius: 6),
            contentMargins: [
                DynamicIsland.ContentMargins(edges: "horizontal", length: 20, for: .expanded),
                DynamicIsland.ContentMargins(edges: "bottom", length: 20, for: .expanded)
            ]
        )
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let (hours, minutes, seconds) = (total / 3600, total / 60 % 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    private static func stack(_ kind: Node.Kind, spacing: CGFloat? = nil, _ children: [Node]) -> Node {
        var node = Node(kind)
        node.spacing = spacing
        node.children = children
        return node
    }

    private static func text(_ value: String, style: String, weight: String? = nil, secondary: Bool = false) -> Node {
        var node = Node(.text)
        node.text = value
        node.lineLimit = 1
        node.font = FontSpec(style: style, weight: weight)
        node.foregroundStyle = secondary ? "secondary" : nil
        return node
    }

    private static func player(_ media: NowPlaying) -> Node {
        var icon = Node(.image)
        icon.app = media.bundleIdentifier
        icon.frame = Frame(width: 16, height: 16)
        return stack(.hStack, spacing: 6, [
            icon,
            text(media.name, style: "footnote", weight: "medium", secondary: true)
        ])
    }

    private static func opening(_ application: String?, _ artwork: Node) -> Node {
        guard let application else { return artwork }
        var link = Node(.link)
        link.destination = application
        link.children = [artwork]
        return link
    }

    private static func details(_ media: NowPlaying, _ interval: [Double]?) -> Node {
        var titles = stack(.vStack, spacing: 1, [
            text(media.title, style: "subheadline", weight: "semibold"),
            text(media.artist, style: "subheadline", secondary: true)
        ])
        titles.alignment = "leading"
        titles.frame = Frame(maxWidth: .infinity, alignment: "leading")

        var controls = stack(.hStack, spacing: 18, [
            control(.previous, "backward.fill", size: 18, media),
            control(.playPause, media.playing ? "pause.fill" : "play.fill", size: 26, media),
            control(.next, "forward.fill", size: 18, media)
        ])
        controls.frame = Frame(maxWidth: .infinity)

        var details = stack(
            .vStack,
            spacing: 0,
            [titles, Node(.spacer), controls, Node(.spacer)] + progress(media, interval)
        )
        details.alignment = "leading"
        details.frame = Frame(height: cover, maxWidth: .infinity)
        return details
    }

    private static func progress(_ media: NowPlaying, _ interval: [Double]?) -> [Node] {
        guard media.duration > 0 else { return [] }

        var slider = Node(.slider)
        slider.intent = media.commands.contains(.seek) ? NowPlaying.Command.seek.rawValue : nil
        slider.timerInterval = interval
        slider.value = interval == nil ? media.elapsed : nil
        slider.total = interval == nil ? media.duration : nil
        slider.frame = Frame(maxWidth: .infinity)

        return [
            slider,
            stack(.hStack, [
                time(interval, countsDown: false, paused: media.elapsed),
                Node(.spacer),
                time(interval, countsDown: true, paused: media.duration - media.elapsed)
            ])
        ]
    }

    private static func artwork(_ media: NowPlaying, side: CGFloat, radius: CGFloat) -> Node {
        var node = Node(.image)
        if let artwork = media.artwork {
            node.source = artwork
            node.contentMode = "fill"
            node.cornerRadius = radius
        } else {
            node.app = media.bundleIdentifier
        }
        node.frame = Frame(width: side, height: side)
        return node
    }

    private static func bars(_ media: NowPlaying, width: CGFloat, height: CGFloat) -> Node {
        var node = Node(.audioBars)
        node.isActive = media.playing
        node.frame = Frame(width: width, height: height)
        return node
    }

    private static func time(_ interval: [Double]?, countsDown: Bool, paused: Double) -> Node {
        var node = Node(.text)
        if let interval {
            node.timerInterval = interval
            node.countsDown = countsDown
        } else {
            node.text = clock(paused)
        }
        node.font = FontSpec(style: "caption", weight: "semibold")
        node.monospacedDigit = true
        node.foregroundStyle = "secondary"
        return node
    }

    private static func control(
        _ command: NowPlaying.Command,
        _ symbol: String,
        size: CGFloat,
        _ media: NowPlaying
    ) -> Node {
        let enabled = media.commands.contains(command)
        var node = Node(enabled ? .button : .image)
        if enabled {
            node.intent = command.rawValue
            node.systemImage = symbol
            node.buttonStyle = "plain"
        } else {
            node.systemName = symbol
            node.opacity = 0.3
        }
        node.font = FontSpec(size: size)
        node.frame = Frame(width: 40, height: 40)
        return node
    }
}
