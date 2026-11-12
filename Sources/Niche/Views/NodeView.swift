import AppKit
import NicheKit
import SwiftUI

struct NodeActions {
    var intent: (String, Bool?, Double?) -> Void = { _, _, _ in }
    var open: (String) -> Void = { _ in }
}

struct NodeView: View {
    let node: Node
    let actions: NodeActions

    @Environment(\.lineLimit) private var inheritedLineLimit

    var body: some View {
        if node.isVisible {
            content
                .frame(width: node.frame?.width, height: node.frame?.height, alignment: Alignment(named: node.frame?.alignment))
                .frame(
                    maxWidth: node.frame?.maxWidth?.value,
                    maxHeight: node.frame?.maxHeight?.value,
                    alignment: Alignment(named: node.frame?.alignment)
                )
                .padding(node.padding?.edges ?? EdgeInsets())
                .background(Color(spec: node.background) ?? .clear)
                .modifier(Rounded(radius: node.cornerRadius))
                .blur(radius: node.blur ?? 0)
                .scaleEffect(node.scaleEffect ?? 1)
                .opacity(node.opacity ?? 1)
                .tracking(node.tracking ?? 0)
                .layoutPriority(node.layoutPriority ?? 0)
        }
    }

    @ViewBuilder private var content: some View {
        switch node.type {
        case .text:
            text
                .font(node.monospacedDigit == true ? font.monospacedDigit() : font)
                .foregroundStyle(foreground)
                .lineLimit(node.lineLimit ?? inheritedLineLimit)
                .contentTransition(.numericText())
        case .image:
            image
        case .label:
            HStack(spacing: node.spacing ?? 6) {
                Image(systemName: node.systemImage ?? "questionmark")
                Text(node.title ?? "")
            }
            .font(font)
            .foregroundStyle(foreground)
            .lineLimit(1)
        case .progressView:
            ProgressNode(node: node, tint: tint)
        case .slider:
            SliderNode(node: node, tint: Color(spec: node.tint) ?? .white) { value in
                if let intent = node.intent { actions.intent(intent, nil, value) }
            }
        case .hStack:
            HStack(alignment: Alignment(named: node.alignment).vertical, spacing: node.spacing) { children }
        case .vStack:
            VStack(alignment: Alignment(named: node.alignment).horizontal, spacing: node.spacing) { children }
        case .zStack:
            ZStack(alignment: Alignment(named: node.alignment)) { children }
        case .spacer:
            Spacer(minLength: node.minLength ?? 0)
        case .button:
            Button {
                if let intent = node.intent { actions.intent(intent, nil, nil) }
            } label: {
                bordered(prominent: node.buttonStyle == "borderedProminent")
            }
            .buttonStyle(PressStyle())
        case .toggle:
            Button {
                if let intent = node.intent { actions.intent(intent, !(node.isOn ?? false), nil) }
            } label: {
                bordered(prominent: node.isOn == true)
                    .opacity(node.buttonStyle == "plain" && node.isOn != true ? 0.45 : 1)
            }
            .buttonStyle(PressStyle())
        case .link:
            Button {
                if let destination = node.destination { actions.open(destination) }
            } label: {
                label.foregroundStyle(foreground).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
        case .video:
            if let url = fileURL {
                VideoNode(url: url)
                    .frame(width: node.frame?.width ?? 32, height: node.frame?.height ?? 32)
            }
        case .webView:
            WebNode(source: node.source, html: node.html) { actions.intent($0, nil, nil) }
        case .audioBars:
            AudioBarsNode(active: node.isActive ?? true, color: Color(spec: node.tint) ?? foreground)
                .frame(width: node.frame?.width ?? 16, height: node.frame?.height ?? 14)
        }
    }

    private var children: some View {
        ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
            NodeView(node: child, actions: actions)
        }
    }

    @ViewBuilder private var label: some View {
        if node.children != nil {
            HStack(alignment: Alignment(named: node.alignment).vertical, spacing: node.spacing) { children }
        } else if let systemImage = node.systemImage, let title = node.title {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(font)
        } else if let systemImage = node.systemImage {
            Image(systemName: systemImage).font(font)
        } else {
            Text(node.title ?? node.text ?? "").font(font)
        }
    }

    @ViewBuilder private func bordered(prominent: Bool) -> some View {
        if node.buttonStyle == "plain" {
            label
                .foregroundStyle(foreground)
                .frame(width: node.frame?.width, height: node.frame?.height)
                .frame(minWidth: 30, minHeight: 30)
                .modifier(HoverHighlight())
        } else {
            label
                .lineLimit(1)
                .foregroundStyle(Color(spec: node.foregroundStyle) ?? (prominent ? .white : tint))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(prominent ? tint : tint.opacity(0.2), in: Capsule())
                .contentShape(Capsule())
        }
    }

    private var text: Text {
        if let interval = node.timerInterval, interval.count == 2, interval[0] <= interval[1] {
            let range = Date(timeIntervalSince1970: interval[0])...Date(timeIntervalSince1970: interval[1])
            return Text(timerInterval: range, countsDown: node.countsDown ?? true)
        }
        if let date = node.date.map(Date.init(timeIntervalSince1970:)) {
            let style: Text.DateStyle = switch node.style {
            case "relative": .relative
            case "offset": .offset
            case "time": .time
            case "date": .date
            default: .timer
            }
            return Text(date, style: style)
        }
        return Text(node.text ?? "")
    }

    @ViewBuilder private var image: some View {
        if let systemName = node.systemName {
            let symbol = Image(systemName: systemName)
                .font(font)
                .foregroundStyle(foreground)

            switch node.symbolEffect {
            case "pulse": symbol.symbolEffect(.pulse)
            case "variableColor": symbol.symbolEffect(.variableColor.iterative)
            default: symbol
            }
        } else {
            let mode: ContentMode = node.contentMode == "fill" ? .fill : .fit
            let width = node.frame?.width ?? node.frame?.height ?? 22
            let height = node.frame?.height ?? node.frame?.width ?? 22

            Group {
                if let source = node.source, source.hasPrefix("http"), let url = URL(string: source) {
                    RemoteImage(url: url, mode: mode)
                } else if let picture = localImage {
                    Image(nsImage: picture).resizable().aspectRatio(contentMode: mode)
                }
            }
            .frame(width: width, height: height)
            .clipped()
        }
    }

    private var localImage: NSImage? {
        if let app = node.app, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return fileURL.flatMap { NSImage(contentsOf: $0) }
    }

    private var fileURL: URL? {
        node.source.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
    }

    private var foreground: Color {
        Color(spec: node.foregroundStyle) ?? .white
    }

    private var tint: Color {
        Color(spec: node.tint) ?? Color(spec: "blue") ?? .blue
    }

    private var font: Font {
        Font(spec: node.font)
    }
}
