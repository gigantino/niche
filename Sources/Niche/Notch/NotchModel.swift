import NicheKit
import SwiftUI

@MainActor
@Observable
final class NotchModel {
    let center: ActivityCenter
    var geometry: NotchGeometry?
    private(set) var isHovering = false
    private var expandedID: String?
    private var leadingWidth: CGFloat = 0
    private var trailingWidth: CGFloat = 0
    private var expandedHeight: CGFloat = 0

    @ObservationIgnored var onCaptureChange: ((Bool) -> Void)?

    @ObservationIgnored private let environment: NotchEnvironment
    @ObservationIgnored private let timing: NotchTiming
    @ObservationIgnored private var lastHaptic = Date.distantPast
    @ObservationIgnored private var tracking: Task<Void, Never>?
    @ObservationIgnored private var alertDismissal: Task<Void, Never>?
    @ObservationIgnored private var press: (id: String, hold: Task<Void, Never>)?
    @ObservationIgnored private var pointerEntered = false
    @ObservationIgnored private var capturing = false
    @ObservationIgnored private var hoverChange: (target: Bool, task: Task<Void, Never>)?
    @ObservationIgnored private var leaveCollapse: Task<Void, Never>?
    @ObservationIgnored private var expandedAt = Date.distantPast
    @ObservationIgnored private var collapsedAt = Date.distantPast
    @ObservationIgnored private var heights: [String: CGFloat] = [:]

    init(center: ActivityCenter, environment: NotchEnvironment = .live, timing: NotchTiming = NotchTiming()) {
        self.center = center
        self.environment = environment
        self.timing = timing
        center.animate = { transition, change in withAnimation(transition.animation, change) }
        center.onAlert = { [weak self] id, alert in self?.present(alert, for: id) }
    }

    var primary: LiveActivity? {
        center.presented.first
    }

    var detached: LiveActivity? {
        let presented = center.presented
        return presented.count > 1 ? presented[1] : nil
    }

    var isMinimal: Bool {
        center.presented.count > 1
    }

    var expanded: LiveActivity? {
        guard let expandedID else { return nil }
        return center.presented.first { $0.id == expandedID && $0.island.hasExpanded }
    }

    var wings: (leading: CGFloat, trailing: CGFloat) {
        guard let island = primary?.island else { return (0, 0) }
        if isMinimal {
            let range = NotchGeometry.minimalWidth
            return (island.attached == nil ? 0 : min(max(leadingWidth, range.lowerBound), range.upperBound), 0)
        }
        return (
            island.compactLeading == nil ? 0 : leadingWidth,
            island.compactTrailing == nil ? 0 : trailingWidth
        )
    }

    var expandedSize: CGSize? {
        guard let geometry, expanded != nil else { return nil }
        let measured = expandedHeight > 0 ? expandedHeight : geometry.notch.height + 60
        return CGSize(
            width: geometry.expandedWidth,
            height: min(max(measured, NotchGeometry.expandedMinHeight), NotchGeometry.expandedMaxHeight)
        )
    }

    func actions(for id: String) -> NodeActions {
        NodeActions(
            intent: { [weak self] intent, isOn, value in
                self?.center.intent(intent, from: id, isOn: isOn, value: value)
            },
            open: { [weak self] url in self?.open(url, for: id) }
        )
    }

    @discardableResult
    func expand(_ id: String) -> Bool {
        guard geometry != nil, center.presented.contains(where: { $0.id == id && $0.island.hasExpanded }) else {
            return false
        }
        alertDismissal?.cancel()
        leaveCollapse?.cancel()
        leaveCollapse = nil
        hoverChange?.task.cancel()
        hoverChange = nil
        pointerEntered = false
        if expandedID != id {
            expandedAt = Date()
            expandedHeight = heights[id] ?? 0
            withAnimation(.notch(stiffness: 170, damping: 21)) {
                expandedID = id
                isHovering = false
            }
        }

        if tracking == nil {
            tracking = Task {
                while !Task.isCancelled {
                    if expanded == nil {
                        collapse()
                    } else {
                        pointerMoved(to: environment.pointerLocation())
                    }
                    try? await Task.sleep(for: .seconds(timing.poll))
                }
            }
        }
        return true
    }

    func collapse() {
        guard expandedID != nil else { return }
        withAnimation(.notch(stiffness: 170, damping: 20)) {
            expandedID = nil
        }
        collapsedAt = Date()
        tracking?.cancel()
        tracking = nil
        alertDismissal?.cancel()
        leaveCollapse?.cancel()
        leaveCollapse = nil
        capture(false)
    }

    func pointerMoved(to location: CGPoint) {
        guard let geometry else { return }

        if let size = expandedSize {
            let inside = geometry.expandedZone(height: size.height).insetBy(dx: -10, dy: -10).contains(location)
            capture(inside)
            if inside {
                pointerEntered = true
                leaveCollapse?.cancel()
                leaveCollapse = nil
            } else if pointerEntered, leaveCollapse == nil, !isPressing {
                let wait = max(timing.collapseGrace, timing.minimumOpen - Date().timeIntervalSince(expandedAt))
                leaveCollapse = Task {
                    try? await Task.sleep(for: .seconds(wait))
                    guard !Task.isCancelled else { return }
                    leaveCollapse = nil
                    guard !isPressing else { return }
                    collapse()
                    tap()
                }
            }
            return
        }

        let inside = mainZone(in: geometry).contains(location)
        if inside == isHovering {
            hoverChange?.task.cancel()
            hoverChange = nil
        } else if hoverChange?.target != inside {
            hoverChange?.task.cancel()
            hoverChange = (inside, Task {
                try? await Task.sleep(for: .seconds(inside ? timing.hoverEnter : timing.hoverLeave))
                guard !Task.isCancelled else { return }
                hoverChange = nil
                guard expandedID == nil, let geometry = self.geometry,
                      mainZone(in: geometry).contains(environment.pointerLocation()) == inside,
                      inside != isHovering
                else { return }

                withAnimation(.notch(stiffness: inside ? 250 : 200, damping: inside ? 14 : 20)) {
                    isHovering = inside
                }
                if inside { tap() }
            })
        }
    }

    func pointerPressed(at location: CGPoint) {
        guard let geometry else { return }

        if let size = expandedSize {
            if !geometry.expandedZone(height: size.height).contains(location) { collapse() }
            return
        }
        guard let activity = target(at: location, in: geometry) else { return }

        let id = activity.id
        press?.hold.cancel()
        press = (id, Task {
            try? await Task.sleep(for: .seconds(timing.hold))
            guard !Task.isCancelled, press?.id == id else { return }
            press = nil
            if expand(id) { tap() }
        })
    }

    func pointerReleased(at location: CGPoint) {
        guard let press else { return }
        press.hold.cancel()
        self.press = nil

        guard let geometry, let activity = target(at: location, in: geometry), activity.id == press.id,
              Date().timeIntervalSince(collapsedAt) > timing.reopenLockout
        else { return }
        if let url = activity.island.widgetURL {
            open(url, for: activity.id)
        } else {
            expand(activity.id)
        }
    }

    func tappedExpanded(_ activity: LiveActivity) {
        guard let url = activity.island.widgetURL else { return }
        open(url, for: activity.id)
        collapse()
    }

    func haptic(strength: Int32?) {
        environment.haptic(strength ?? 6)
    }

    func measured(_ width: CGFloat, edge: HorizontalEdge) {
        withAnimation(.notch(stiffness: 150, damping: 20)) {
            switch edge {
            case .leading: leadingWidth = width
            case .trailing: trailingWidth = width
            }
        }
    }

    func measuredExpanded(height: CGFloat) {
        if let expandedID { heights[expandedID] = height }
        withAnimation(.notch(stiffness: 170, damping: 21)) {
            expandedHeight = height
        }
    }

    private var isPressing: Bool {
        environment.isPressing()
    }

    private func mainZone(in geometry: NotchGeometry) -> CGRect {
        let wings = wings
        let slack: CGFloat = isHovering ? -5 : 0
        return geometry.mainZone(hovering: isHovering, leading: wings.leading, trailing: wings.trailing)
            .insetBy(dx: slack, dy: slack)
    }

    private func target(at location: CGPoint, in geometry: NotchGeometry) -> LiveActivity? {
        if mainZone(in: geometry).contains(location) {
            return primary
        }
        if geometry.detachedZone.contains(location) {
            return detached
        }
        return nil
    }

    private func present(_ alert: AlertConfiguration, for id: String) {
        tap()
        environment.playSound(alert.sound)

        guard expandedID == nil || alertDismissal != nil, expand(id) else { return }
        alertDismissal = Task {
            try? await Task.sleep(for: .seconds(timing.alert))
            guard !Task.isCancelled else { return }
            alertDismissal = nil
            if !pointerEntered { collapse() }
        }
    }

    private func open(_ url: String, for id: String) {
        center.opened(url, from: id)
        if let url = URL(string: url) { environment.open(url) }
    }

    private func capture(_ value: Bool) {
        guard value != capturing else { return }
        capturing = value
        onCaptureChange?(value)
    }

    private func tap() {
        let now = Date()
        guard now.timeIntervalSince(lastHaptic) >= timing.hapticGap else { return }
        lastHaptic = now
        environment.haptic(6)
    }
}
