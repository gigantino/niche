import Foundation
import NowPlayingWire

struct MediaVisibility {
    enum Phase: Equatable {
        case idle
        case active(player: String)
        case paused(player: String, since: Date)
    }

    let pauseGrace: TimeInterval
    private(set) var phase = Phase.idle

    init(pauseGrace: TimeInterval = 5) {
        self.pauseGrace = pauseGrace
    }

    var deadline: Date? {
        guard case .paused(_, let since) = phase else { return nil }
        return since.addingTimeInterval(pauseGrace)
    }

    mutating func shows(_ media: NowPlaying?, fillsScreen: Bool, expanded: Bool, at now: Date) -> Bool {
        phase = next(for: media, expanded: expanded, at: now)
        return phase != .idle && !fillsScreen
    }

    private func next(for media: NowPlaying?, expanded: Bool, at now: Date) -> Phase {
        guard let player = media?.bundleIdentifier else { return .idle }
        if media?.playing == true { return .active(player: player) }

        switch phase {
        case .active(player):
            return expanded ? phase : .paused(player: player, since: now)
        case .paused(player, let since):
            if expanded { return .active(player: player) }
            return now.timeIntervalSince(since) < pauseGrace ? phase : .idle
        default:
            return .idle
        }
    }
}
