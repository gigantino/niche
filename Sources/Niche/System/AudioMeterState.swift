import Foundation

struct AudioMeterState {
    static let latencyInterval: TimeInterval = 1

    private var listeners = 0
    private var departures = 0
    private var analyzer: AudioAnalyzer?
    private var delay = LevelDelay()
    private var latency: TimeInterval = 0
    private var latencyRead = -TimeInterval.infinity

    var needsTap: Bool {
        listeners > 0 && analyzer == nil
    }

    mutating func attach() -> Bool {
        listeners += 1
        return listeners == 1
    }

    mutating func detach() -> Int {
        listeners -= 1
        departures += 1
        return departures
    }

    func isIdle(since departure: Int) -> Bool {
        listeners == 0 && departures == departure
    }

    mutating func started(sampleRate: Float) {
        analyzer = AudioAnalyzer(sampleRate: sampleRate)
        delay = LevelDelay()
        latencyRead = -.infinity
    }

    mutating func stopped() {
        analyzer = nil
        delay = LevelDelay()
    }

    mutating func receive(_ samples: [Float], at time: TimeInterval) -> (firstSound: Bool, measures: Bool) {
        guard analyzer != nil else { return (false, false) }

        let wasHeard = analyzer?.heard == true
        for frame in analyzer?.add(samples) ?? [] {
            delay.add(frame, at: time)
        }
        let measures = time - latencyRead >= Self.latencyInterval
        if measures { latencyRead = time }
        return (!wasHeard && analyzer?.heard == true, measures)
    }

    mutating func measured(latency: TimeInterval) {
        self.latency = latency
    }

    func levels(at time: TimeInterval) -> [Float]? {
        delay.values(at: time, delay: latency)
    }
}
