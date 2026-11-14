import CoreGraphics
import Foundation
import ImageIO

struct ArtworkTint {
    static let side = 32
    static let leadingBrightness = 0.85
    static let trailingBrightness = 0.6
    static let saturation = 0.5...0.9
    static let leastColour = 0.01
    static let leastSecondHue = 0.15

    let leading: String
    let trailing: String

    var gradient: [String] {
        [leading, trailing]
    }

    init(leading: String, trailing: String) {
        self.leading = leading
        self.trailing = trailing
    }

    init?(path: String) {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.side
        ]
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let context = CGContext(
                  data: nil,
                  width: Self.side,
                  height: Self.side,
                  bitsPerComponent: 8,
                  bytesPerRow: Self.side * 4,
                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        guard let data = context.data else { return nil }
        let count = Self.side * Self.side * 4
        self.init(pixels: Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: count)))
    }

    init?(pixels: [UInt8]) {
        var hues = [Sum](repeating: Sum(), count: 12)
        for index in stride(from: 0, to: pixels.count - 3, by: 4) {
            let red = Double(pixels[index]) / 255
            let green = Double(pixels[index + 1]) / 255
            let blue = Double(pixels[index + 2]) / 255
            let brightest = max(red, green, blue)
            let spread = brightest - min(red, green, blue)
            guard spread > 0 else { continue }

            let saturation = spread / brightest
            hues[Self.hue(red, green, blue)].add(red, green, blue, weight: saturation * saturation * brightest)
        }

        let total = hues.reduce(0) { $0 + $1.weight }
        guard total / Double(max(pixels.count / 4, 1)) > Self.leastColour else { return nil }

        let windows = hues.indices.map { hues[($0 + 11) % 12] + hues[$0] + hues[($0 + 1) % 12] }
        guard let first = windows.indices.max(by: { windows[$0].weight < windows[$1].weight }),
              let leading = windows[first].color(brightness: Self.leadingBrightness)
        else { return nil }

        let apart = windows.indices.filter { min(abs($0 - first), 12 - abs($0 - first)) >= 2 }
        let second = apart.max { windows[$0].weight < windows[$1].weight }.map { windows[$0] }
        let other = second.flatMap { $0.weight > windows[first].weight * Self.leastSecondHue ? $0 : nil }
        self.leading = leading
        self.trailing = (other ?? windows[first]).color(brightness: Self.trailingBrightness) ?? leading
    }

    private struct Sum {
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var weight = 0.0

        mutating func add(_ red: Double, _ green: Double, _ blue: Double, weight: Double) {
            self.red += red * weight
            self.green += green * weight
            self.blue += blue * weight
            self.weight += weight
        }

        func color(brightness: Double) -> String? {
            guard weight > 0 else { return nil }
            let (red, green, blue) = (red / weight, green / weight, blue / weight)
            let brightest = max(red, green, blue)
            let darkest = min(red, green, blue)
            guard brightest > darkest else { return nil }

            let saturation = min(
                max((brightest - darkest) / brightest, ArtworkTint.saturation.lowerBound),
                ArtworkTint.saturation.upperBound
            )
            let channel = { (value: Double) -> Int in
                let position = (value - darkest) / (brightest - darkest)
                return Int((brightness * (1 - saturation * (1 - position)) * 255).rounded())
            }
            return String(format: "#%02X%02X%02X", channel(red), channel(green), channel(blue))
        }

        static func + (first: Sum, second: Sum) -> Sum {
            Sum(
                red: first.red + second.red,
                green: first.green + second.green,
                blue: first.blue + second.blue,
                weight: first.weight + second.weight
            )
        }
    }

    private static func hue(_ red: Double, _ green: Double, _ blue: Double) -> Int {
        let brightest = max(red, green, blue)
        let spread = brightest - min(red, green, blue)
        var sextant: Double
        if brightest == red {
            sextant = (green - blue) / spread
        } else if brightest == green {
            sextant = (blue - red) / spread + 2
        } else {
            sextant = (red - green) / spread + 4
        }
        if sextant < 0 { sextant += 6 }
        return Int(sextant * 2) % 12
    }
}
