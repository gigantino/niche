import SwiftUI

struct IslandRegion: Equatable {
    enum Position {
        case leading, trailing, center, bottom
    }

    var position: Position
    var belowIfTooWide = false
    var priority = 0.0
}

struct IslandRegionKey: LayoutValueKey {
    static let defaultValue: IslandRegion? = nil
}

struct IslandLayout: Layout {
    let notch: CGSize
    var spacing: CGFloat = 8
    var topInset: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? notch.width * 2
        let bottom = frames(width: width, subviews: subviews).values.map(\.maxY).max() ?? 0
        return CGSize(width: width, height: max(notch.height, bottom))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, frame) in frames(width: bounds.width, subviews: subviews) {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func frames(width: CGFloat, subviews: Subviews) -> [Int: CGRect] {
        var frames: [Int: CGRect] = [:]
        var columns: [IslandRegion.Position: CGFloat] = [:]
        let side = max(0, (width - notch.width) / 2 - spacing)

        func index(of position: IslandRegion.Position) -> Int? {
            subviews.firstIndex { $0[IslandRegionKey.self]?.position == position }
        }

        let priorities = subviews.compactMap { $0[IslandRegionKey.self]?.priority }
        let highest = priorities.max() ?? 0
        var row = notch.height

        for position in [IslandRegion.Position.leading, .trailing] {
            guard let index = index(of: position) else { continue }
            let priority = subviews[index][IslandRegionKey.self]?.priority ?? 0
            if priority > 0, priority == highest, priorities.filter({ $0 == highest }).count == 1 {
                let fitted = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
                let size = CGSize(width: min(fitted.width, width), height: fitted.height)
                frames[index] = CGRect(
                    origin: CGPoint(x: position == .leading ? 0 : width - size.width, y: notch.height),
                    size: size
                )
                row = notch.height + size.height + spacing
                continue
            }

            let ideal = subviews[index].sizeThatFits(.unspecified)
            let below = subviews[index][IslandRegionKey.self]?.belowIfTooWide == true && ideal.width > side
            let limit = below ? (width - spacing) / 2 : side
            let fitted = subviews[index].sizeThatFits(ProposedViewSize(width: min(ideal.width, limit), height: nil))
            let size = CGSize(width: min(fitted.width, limit), height: fitted.height)

            let y = below ? notch.height : size.height <= notch.height ? (notch.height - size.height) / 2 : topInset
            let frame = CGRect(origin: CGPoint(x: position == .leading ? 0 : width - size.width, y: y), size: size)
            frames[index] = frame
            if frame.maxY > notch.height { columns[position] = size.width + spacing }
        }

        if let index = index(of: .center) {
            let leading = columns[.leading] ?? 0
            let available = max(0, width - leading - (columns[.trailing] ?? 0))
            let fitted = subviews[index].sizeThatFits(ProposedViewSize(width: available, height: nil))
            let size = CGSize(width: min(fitted.width, available), height: fitted.height)
            frames[index] = CGRect(
                origin: CGPoint(x: leading + (available - size.width) / 2, y: row),
                size: size
            )
        }

        if let index = index(of: .bottom) {
            let above = frames.values.map(\.maxY).max() ?? 0
            let fitted = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let size = CGSize(width: min(fitted.width, width), height: fitted.height)
            frames[index] = CGRect(
                origin: CGPoint(x: (width - size.width) / 2, y: max(notch.height, above + spacing)),
                size: size
            )
        }
        return frames
    }
}
