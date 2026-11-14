import Foundation
import NowPlayingWire

extension NowPlaying {
    func position(at now: Date) -> Double {
        guard playing else { return elapsed }
        let position = elapsed + (now.timeIntervalSince1970 - timestamp) * rate
        return duration > 0 ? min(max(position, 0), duration) : max(position, 0)
    }

    func start(at now: Date, keeping previous: Double?) -> Double {
        let start = now.timeIntervalSince1970 - position(at: now)
        if playing, let previous, abs(previous - start) < 1.5 { return previous }
        return start
    }
}

@MainActor
protocol NowPlayingSource: AnyObject {
    var onChange: ((NowPlaying?) -> Void)? { get set }
    func start()
    func send(_ command: NowPlaying.Command, position: Double?)
}
