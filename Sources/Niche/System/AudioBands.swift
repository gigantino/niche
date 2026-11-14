import Accelerate
import Foundation

enum AudioBands {
    struct Band {
        let low: Float
        let high: Float
        let offset: Float
        let slope: Float

        func level(at decibels: Float) -> Float {
            min(max(offset + slope * decibels, AudioBands.floor), 1)
        }
    }

    static let size = 2048
    static let hop = 1024
    static let floor: Float = 3.0 / 42
    static let silence: Float = -150
    static let audible = silence + 30

    static let bands = [
        Band(low: 20, high: 57, offset: 0.22, slope: 0.044),
        Band(low: 71, high: 180, offset: 0.30, slope: 0.012),
        Band(low: 202, high: 570, offset: 0.71, slope: 0.028),
        Band(low: 640, high: 1437, offset: 0.87, slope: 0.024),
        Band(low: 1613, high: 4561, offset: 1.13, slope: 0.027),
        Band(low: 5120, high: 10240, offset: 1.26, slope: 0.031)
    ]

    private static let window = vDSP.window(
        ofType: Float.self, usingSequence: .hanningDenormalized, count: size, isHalfWindow: false
    )
    private static let windowPower = vDSP.sumOfSquares(window)
    private nonisolated(unsafe) static let transform = try? vDSP.DiscreteFourierTransform(
        count: size, direction: .forward, transformType: .complexComplex, ofType: Float.self
    )

    static func decibels(of samples: [Float], sampleRate: Float) -> [Float] {
        guard samples.count == size, sampleRate > 0, let transform else {
            return [Float](repeating: silence, count: bands.count)
        }

        let spectrum = transform.transform(
            real: vDSP.multiply(samples, window),
            imaginary: [Float](repeating: 0, count: size)
        )
        let power = vDSP.add(vDSP.square(spectrum.real), vDSP.square(spectrum.imaginary))
        let half = size / 2
        let resolution = sampleRate / Float(size)

        return bands.map { band in
            let first = min(Int((band.low / resolution).rounded(.up)), half - 1)
            let last = min(max(Int((band.high / resolution).rounded(.up)), first + 1), half)
            return max(10 * log10(vDSP.mean(power[first..<last]) / windowPower + 1e-15), silence)
        }
    }
}

struct AudioLevels {
    static let smoothing: Float = 0.65

    private(set) var values = [Float](repeating: AudioBands.floor, count: AudioBands.bands.count)

    mutating func update(decibels: [Float]) -> [Float] {
        for index in values.indices {
            values[index] += (AudioBands.bands[index].level(at: decibels[index]) - values[index]) * Self.smoothing
        }
        return values
    }
}
