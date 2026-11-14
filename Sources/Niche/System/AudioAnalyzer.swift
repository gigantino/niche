import Foundation

struct AudioAnalyzer {
    private let sampleRate: Float
    private var samples: [Float] = []
    private var levels = AudioLevels()
    private(set) var heard = false

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
    }

    mutating func add(_ incoming: [Float]) -> [[Float]] {
        samples.append(contentsOf: incoming)
        var frames: [[Float]] = []
        while samples.count >= AudioBands.size {
            let decibels = AudioBands.decibels(of: Array(samples.prefix(AudioBands.size)), sampleRate: sampleRate)
            samples.removeFirst(AudioBands.hop)
            heard = heard || decibels.contains { $0 > AudioBands.audible }
            let frame = levels.update(decibels: decibels)
            if heard { frames.append(frame) }
        }
        return frames
    }
}

struct LevelDelay {
    static let span = AudioOutput.longestLatency + 0.5

    private var frames: [(time: TimeInterval, values: [Float])] = []

    mutating func add(_ values: [Float], at time: TimeInterval) {
        frames.append((time, values))
        if let lastTooOld = frames.lastIndex(where: { $0.time < time - Self.span }) {
            frames.removeFirst(lastTooOld)
        }
    }

    func values(at time: TimeInterval, delay: TimeInterval) -> [Float]? {
        frames.last { $0.time <= time - delay }?.values
    }
}
