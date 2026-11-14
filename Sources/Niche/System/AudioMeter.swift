import Foundation
import OSLog
import os

final class AudioMeter: Sendable {
    static let shared = AudioMeter()
    static let grace: TimeInterval = 2

    final class Listener: Sendable {
        private let meter: AudioMeter

        fileprivate init(_ meter: AudioMeter) {
            self.meter = meter
            meter.attach()
        }

        deinit {
            meter.detach()
        }
    }

    private struct Session {
        var state = AudioMeterState()
        var tap: AudioTap?
    }

    private let session = OSAllocatedUnfairLock(initialState: Session())
    private let queue = DispatchQueue(label: "ch.ggtn.niche.audio", qos: .userInteractive)
    private let log = Logger(subsystem: "ch.ggtn.niche", category: "audio")

    var levels: [Float]? {
        let now = ProcessInfo.processInfo.systemUptime
        return session.withLock { $0.state.levels(at: now) }
    }

    func listen() -> Listener {
        Listener(self)
    }

    private func attach() {
        guard session.withLock({ $0.state.attach() }), #available(macOS 14.2, *) else { return }
        queue.async { self.start() }
    }

    private func detach() {
        let departure = session.withLock { $0.state.detach() }
        queue.asyncAfter(deadline: .now() + Self.grace) {
            if self.session.withLock({ $0.state.isIdle(since: departure) }) { self.stop() }
        }
    }

    private func start() {
        guard session.withLock({ $0.state.needsTap }) else { return }
        guard let tap = AudioTap(queue: queue, receive: { [weak self] in self?.receive($0) }) else {
            log.error("the audio tap could not be started")
            return
        }

        log.notice("listening at \(tap.sampleRate, privacy: .public) Hz")
        session.withLock { session in
            session.tap = tap
            session.state.started(sampleRate: tap.sampleRate)
        }
    }

    private func stop() {
        let tap = session.withLock { session in
            session.state.stopped()
            defer { session.tap = nil }
            return session.tap
        }
        if tap != nil { log.notice("stopped listening") }
    }

    private func receive(_ samples: [Float]) {
        let now = ProcessInfo.processInfo.systemUptime
        let (firstSound, measures) = session.withLock { $0.state.receive(samples, at: now) }
        if measures {
            let latency = AudioOutput.latency
            session.withLock { $0.state.measured(latency: latency) }
        }
        if firstSound { log.notice("audio is arriving") }
    }
}
