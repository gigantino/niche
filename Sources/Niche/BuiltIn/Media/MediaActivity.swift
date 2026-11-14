import AppKit
import NicheKit
import NowPlayingWire
import OSLog

@MainActor
final class MediaActivity: BuiltInActivity {
    static let id = "media"

    private let source: any NowPlayingSource
    private let fillsScreen: (NowPlaying) -> Bool
    private var visibility: MediaVisibility
    private var media: NowPlaying?
    private var anchor: Double?
    private var presented: JSONValue?
    private var wake: Task<Void, Never>?
    private var panelOpen = false
    private weak var center: ActivityCenter?
    private weak var notch: NotchModel?
    private let log = Logger(subsystem: "ch.ggtn.niche", category: "media")

    init(
        source: any NowPlayingSource = NowPlayingMonitor(),
        fillsScreen: @escaping (NowPlaying) -> Bool = { media in
            FullScreen.isOwned(
                by: media.pid,
                or: media.bundleIdentifier,
                on: NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            )
        },
        visibility: MediaVisibility = MediaVisibility()
    ) {
        self.source = source
        self.fillsScreen = fillsScreen
        self.visibility = visibility
    }

    func start(center: ActivityCenter, notch: NotchModel) {
        self.center = center
        self.notch = notch

        center.onIntent(for: Self.id) { [weak self] intent, _, value in
            guard let command = NowPlaying.Command(rawValue: intent) else { return }
            self?.source.send(command, position: value)
        }
        source.onChange = { [weak self] media in
            self?.media = media
            self?.refresh()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.spaceChanged() }
        }
        observePanel()
        source.start()
    }

    func refresh() {
        wake?.cancel()
        let now = Date()

        let fillsScreen = media.map(fillsScreen) ?? false
        guard visibility.shows(media, fillsScreen: fillsScreen, expanded: isExpanded, at: now), let media else {
            hide()
            return
        }
        show(media, at: now)

        guard let deadline = visibility.deadline else { return }
        wake = Task {
            try? await Task.sleep(for: .seconds(deadline.timeIntervalSince(now) + 0.02))
            guard !Task.isCancelled else { return }
            refresh()
        }
    }

    private var isExpanded: Bool {
        notch?.expanded?.id == Self.id
    }

    private func observePanel() {
        let open = withObservationTracking {
            isExpanded
        } onChange: { [weak self] in
            Task { @MainActor in self?.observePanel() }
        }
        guard open != panelOpen else { return }
        panelOpen = open
        refresh()
    }

    private func spaceChanged() {
        refresh()
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            refresh()
        }
    }

    private func show(_ media: NowPlaying, at now: Date) {
        let start = media.start(at: now, keeping: anchor)
        anchor = media.playing ? start : nil

        let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: media.bundleIdentifier)
        let island = Media.island(
            for: media,
            start: start,
            application: application?.absoluteString
        )

        do {
            let island = try JSONValue(encoding: island)
            guard island != presented else { return }
            if presented == nil || (try? center?.update(Self.id, dynamicIsland: island)) == nil {
                try center?.request(id: Self.id, attributesType: "Media", dynamicIsland: island)
            }
            presented = island
        } catch {
            log.error("\(String(describing: error), privacy: .public)")
        }
    }

    private func hide() {
        guard presented != nil else { return }
        presented = nil
        anchor = nil
        try? center?.end(Self.id, dismissalPolicy: .immediate)
    }
}
