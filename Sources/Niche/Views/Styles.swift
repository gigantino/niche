import NicheKit
import SwiftUI

struct Rounded: ViewModifier {
    let radius: CGFloat?

    func body(content: Content) -> some View {
        if let radius {
            content.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            content
        }
    }
}

struct HoverHighlight: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(.white.opacity(hovering ? 0.14 : 0), in: Capsule())
            .contentShape(Capsule())
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.interpolatingSpring(mass: 1, stiffness: 160, damping: 18), value: configuration.isPressed)
    }
}

extension Insets {
    var edges: EdgeInsets {
        EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }
}

extension Alignment {
    init(named name: String?) {
        self = switch name {
        case "leading": .leading
        case "trailing": .trailing
        case "top": .top
        case "bottom": .bottom
        case "topLeading": .topLeading
        case "topTrailing": .topTrailing
        case "bottomLeading": .bottomLeading
        case "bottomTrailing": .bottomTrailing
        default: .center
        }
    }
}

extension Color {
    init?(spec: String?) {
        guard let spec else { return nil }

        let system: [String: UInt64] = [
            "red": 0xFF453A, "orange": 0xFF9F0A, "yellow": 0xFFD60A, "green": 0x30D158,
            "mint": 0x63E6E2, "teal": 0x40C8E0, "cyan": 0x64D2FF, "blue": 0x0A84FF,
            "indigo": 0x5E5CE6, "purple": 0xBF5AF2, "pink": 0xFF375F, "brown": 0xAC8E68,
            "gray": 0x8E8E93, "accentColor": 0x0A84FF
        ]

        switch spec {
        case "white", "primary": self = .white
        case "black": self = .black
        case "clear": self = .clear
        case "secondary": self = Color(red: 0.92, green: 0.92, blue: 0.96, opacity: 0.6)
        case "tertiary": self = Color(red: 0.92, green: 0.92, blue: 0.96, opacity: 0.3)
        case let name where system[name] != nil:
            let rgb = system[name] ?? 0
            self = Color(
                red: Double(rgb >> 16 & 0xFF) / 255,
                green: Double(rgb >> 8 & 0xFF) / 255,
                blue: Double(rgb & 0xFF) / 255
            )
        default:
            let hex = spec.hasPrefix("#") ? String(spec.dropFirst()) : spec
            guard hex.count == 6 || hex.count == 8, let number = UInt64(hex, radix: 16) else { return nil }
            let rgba = hex.count == 6 ? number << 8 | 0xFF : number
            self = Color(
                red: Double(rgba >> 24 & 0xFF) / 255,
                green: Double(rgba >> 16 & 0xFF) / 255,
                blue: Double(rgba >> 8 & 0xFF) / 255,
                opacity: Double(rgba & 0xFF) / 255
            )
        }
    }
}

extension Font {
    init(spec: FontSpec?) {
        let fallback: Font.Weight = spec?.style == "headline" ? .semibold : .regular
        let weight: Font.Weight = switch spec?.weight {
        case "ultraLight": .ultraLight
        case "thin": .thin
        case "light": .light
        case "regular": .regular
        case "medium": .medium
        case "semibold": .semibold
        case "bold": .bold
        case "heavy": .heavy
        case "black": .black
        default: fallback
        }
        let design: Font.Design = switch spec?.design {
        case "rounded": .rounded
        case "monospaced": .monospaced
        case "serif": .serif
        default: .default
        }
        let size: CGFloat = switch spec?.style {
        case "largeTitle": 34
        case "title": 28
        case "title2": 22
        case "title3": 20
        case "subheadline": 15
        case "callout": 16
        case "footnote": 13
        case "caption": 12
        case "caption2": 11
        default: 17
        }
        self = .system(size: spec?.size ?? size, weight: weight, design: design)
    }
}
