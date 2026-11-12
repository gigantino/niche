import NicheKit
import SwiftUI

struct NotchView: View {
    let model: NotchModel

    var body: some View {
        if let geometry = model.geometry {
            ZStack(alignment: .top) {
                island(geometry)
                detached(geometry)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func island(_ geometry: NotchGeometry) -> some View {
        let hovering = model.isHovering
        let expanded = model.expanded
        let primary = model.primary
        let minimal = model.isMinimal
        let wings = model.wings
        let ear = expanded != nil
            ? NotchGeometry.expandedEar
            : hovering || wings.leading + wings.trailing > 0 ? NotchGeometry.ear : 0
        let size = model.expandedSize
            ?? CGSize(width: geometry.notch.width + wings.leading + wings.trailing, height: geometry.notch.height)
        let shape = NotchShape(
            earRadius: ear,
            bottomRadius: expanded != nil ? NotchGeometry.expandedRadius : hovering ? 12 : 11
        )

        return shape
            .fill(.black)
            .overlay {
                ZStack(alignment: .top) {
                    if let expanded {
                        ExpandedIsland(activity: expanded, geometry: geometry, model: model)
                            .id(expanded.id)
                            .transition(.panel)
                    } else {
                        HStack(spacing: 0) {
                            WingSlot(
                                node: minimal ? primary?.island.attached : primary?.island.compactLeading,
                                mode: minimal ? .minimal : .compactLeading,
                                activity: primary,
                                edge: .leading,
                                model: model
                            )
                            Spacer(minLength: 0)
                            WingSlot(
                                node: minimal ? nil : primary?.island.compactTrailing,
                                mode: .compactTrailing,
                                activity: primary,
                                edge: .trailing,
                                model: model
                            )
                        }
                        .frame(height: geometry.notch.height)
                        .transition(.opacity.animation(.easeOut(duration: 0.15)))
                    }
                }
                .padding(.horizontal, ear)
            }
            .frame(width: size.width + 2 * ear, height: size.height)
            .clipShape(shape)
            .shadow(
                color: .black.opacity(expanded != nil ? 0.35 : hovering ? 0.25 : 0),
                radius: expanded != nil ? 14 : 8,
                y: 2
            )
            .scaleEffect(hovering && expanded == nil ? NotchGeometry.hoverScale : 1, anchor: .top)
            .offset(x: expanded != nil ? 0 : (wings.trailing - wings.leading) / 2)
    }

    @ViewBuilder private func detached(_ geometry: NotchGeometry) -> some View {
        if model.expanded == nil, let activity = model.detached, let node = activity.island.attached {
            let diameter = geometry.detachedDiameter

            NodeView(node: node, actions: model.actions(for: activity.id))
                .padding(activity.island.margins(for: .minimal, default: Insets()).edges)
                .frame(width: diameter, height: diameter)
                .background(.black, in: Circle())
                .clipShape(Circle())
                .lineLimit(1)
                .offset(x: geometry.detachedOffset, y: (geometry.notch.height - diameter) / 2)
                .id(activity.id)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
    }
}

private struct WingSlot: View {
    let node: Node?
    let mode: DynamicIslandMode
    let activity: LiveActivity?
    let edge: HorizontalEdge
    let model: NotchModel

    var body: some View {
        ZStack {
            if let node, let activity, node.isVisible {
                NodeView(node: node, actions: model.actions(for: activity.id))
                    .padding(activity.island.margins(for: mode, default: margins).edges)
                    .frame(maxWidth: NotchGeometry.compactLimit, alignment: edge == .leading ? .leading : .trailing)
                    .id(activity.id + mode.rawValue)
                    .transition(.wing)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { model.measured($0, edge: edge) }
    }

    private var margins: Insets {
        switch mode {
        case .minimal: Insets(leading: 8, trailing: 6)
        case .compactLeading: Insets(leading: 8, trailing: 3)
        case .compactTrailing, .expanded: Insets(leading: 3, trailing: 8)
        }
    }
}

private struct ExpandedIsland: View {
    let activity: LiveActivity
    let geometry: NotchGeometry
    let model: NotchModel

    var body: some View {
        let regions = activity.island.expanded
        let margins = activity.island.margins(
            for: .expanded,
            default: Insets(top: 0, leading: 18, bottom: 18, trailing: 18)
        )

        IslandLayout(notch: geometry.notch.size) {
            region(regions?.leading, .leading)
            region(regions?.trailing, .trailing)
            region(regions?.center, .center)
            region(regions?.bottom, .bottom)
        }
        .padding(margins.edges)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { model.measuredExpanded(height: $0) }
        .frame(maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { model.tappedExpanded(activity) }
    }

    @ViewBuilder private func region(_ node: Node?, _ position: IslandRegion.Position) -> some View {
        if let node, node.isVisible {
            NodeView(node: node, actions: model.actions(for: activity.id))
                .padding(node.contentMargins?.edges ?? EdgeInsets())
                .layoutValue(
                    key: IslandRegionKey.self,
                    value: IslandRegion(
                        position: position,
                        belowIfTooWide: node.verticalPlacement == "belowIfTooWide",
                        priority: node.priority ?? 0
                    )
                )
        }
    }
}

private struct BlurEffect: ViewModifier {
    let opacity: Double
    let blur: CGFloat
    let scaleX: CGFloat
    let scaleY: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: scaleX, y: scaleY, anchor: .top)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

private extension AnyTransition {
    static var wing: AnyTransition {
        let shown = BlurEffect(opacity: 1, blur: 0, scaleX: 1, scaleY: 1)
        return .asymmetric(
            insertion: .modifier(active: BlurEffect(opacity: 0, blur: 10, scaleX: 0, scaleY: 1), identity: shown)
                .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.3)),
            removal: .modifier(active: BlurEffect(opacity: 0, blur: 8, scaleX: 0.25, scaleY: 1), identity: shown)
                .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.25))
        )
    }

    static var panel: AnyTransition {
        let shown = BlurEffect(opacity: 1, blur: 0, scaleX: 1, scaleY: 1)
        return .asymmetric(
            insertion: .modifier(active: BlurEffect(opacity: 0, blur: 10, scaleX: 0.9, scaleY: 0.7), identity: shown)
                .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.3).delay(0.05)),
            removal: .modifier(active: BlurEffect(opacity: 0, blur: 8, scaleX: 0.9, scaleY: 0.7), identity: shown)
                .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.15))
        )
    }
}
