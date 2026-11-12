import AppKit
import NicheKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let center = ActivityCenter()
    private let model: NotchModel
    private var panel: NotchPanel?
    private var server: Server?
    private var statusItem: NSStatusItem?
    private var monitors: [Any] = []
    private let builtIns = BuiltInActivities.all()

    override init() {
        model = NotchModel(center: center)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        installPointerMonitors()
        layout()

        model.onCaptureChange = { [weak self] capturing in
            self?.panel?.ignoresMouseEvents = !capturing
        }

        for builtIn in builtIns {
            builtIn.start(center: center)
        }

        let model = model
        let server = Server(center: center, host: Server.Host(
            notch: { model.geometry?.notch.size },
            version: { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String },
            haptic: { model.haptic(strength: $0) }
        ))
        do {
            try server.start()
            self.server = server
        } catch {
            Logger(subsystem: "ch.ggtn.niche", category: "server").error("\(error, privacy: .public)")
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(layout),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }

    @objc private func layout() {
        model.geometry = NotchGeometry.current

        guard let geometry = model.geometry else {
            panel?.orderOut(nil)
            return
        }

        if let panel {
            panel.setFrame(geometry.panelFrame, display: true)
            panel.orderFrontRegardless()
        } else {
            let panel = NotchPanel(model: model, frame: geometry.panelFrame)
            panel.orderFrontRegardless()
            self.panel = panel
        }
    }

    private func installPointerMonitors() {
        let events: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseDown, .leftMouseUp
        ]
        let handle: @Sendable (NSEvent.EventType) -> Void = { type in
            MainActor.assumeIsolated {
                guard let model = (NSApp.delegate as? AppDelegate)?.model else { return }
                switch type {
                case .leftMouseDown: model.pointerPressed(at: NSEvent.mouseLocation)
                case .leftMouseUp: model.pointerReleased(at: NSEvent.mouseLocation)
                default: model.pointerMoved(to: NSEvent.mouseLocation)
                }
            }
        }

        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { event in
            handle(event.type)
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { event in
            handle(event.type)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: "Niche"
        )

        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Niche", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }
}
