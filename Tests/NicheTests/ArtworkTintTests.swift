import Foundation
import Testing
@testable import Niche

struct ArtworkTintTests {
    private func pixels(_ colors: [(red: UInt8, green: UInt8, blue: UInt8, count: Int)]) -> [UInt8] {
        colors.flatMap { color in
            Array(repeating: [color.red, color.green, color.blue, 255], count: color.count).flatMap { $0 }
        }
    }

    private func channels(_ hex: String?) -> (red: Int, green: Int, blue: Int)? {
        guard let hex, hex.count == 7, let value = Int(hex.dropFirst(), radix: 16) else { return nil }
        return (value >> 16, value >> 8 & 255, value & 255)
    }

    @Test func theVividPartOfACoverWinsOverItsGreyPart() throws {
        let tint = try #require(channels(ArtworkTint(pixels: pixels([(120, 110, 100, 85), (30, 200, 60, 15)]))?.leading))

        #expect(tint.green > 200)
        #expect(tint.green > tint.red)
        #expect(tint.green > tint.blue)
    }

    @Test func theLastBarTakesTheCoversSecondColourAndIsDimmer() throws {
        let tint = try #require(ArtworkTint(pixels: pixels([(220, 30, 30, 60), (30, 30, 220, 40)])))
        let leading = try #require(channels(tint.leading))
        let trailing = try #require(channels(tint.trailing))

        #expect(leading.red > leading.blue)
        #expect(trailing.blue > trailing.red)
        #expect(max(trailing.red, trailing.green, trailing.blue) < max(leading.red, leading.green, leading.blue))
    }

    @Test func aCoverWithoutColourKeepsTheBarsWhite() {
        #expect(ArtworkTint(pixels: pixels([(0, 0, 0, 50), (255, 255, 255, 30), (90, 90, 90, 20)])) == nil)
        #expect(ArtworkTint(pixels: pixels([(100, 98, 96, 100)])) == nil)
        #expect(ArtworkTint(pixels: []) == nil)
        #expect(ArtworkTint(path: "/nonexistent/cover") == nil)
    }
}
