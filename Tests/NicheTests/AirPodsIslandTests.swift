import Foundation
import NicheKit
import Testing
@testable import Niche

struct AirPodsIslandTests {
    static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/airpods-islands.json")

    let expected = try! JSONDecoder().decode([String: DynamicIsland].self, from: Data(contentsOf: fixtures))

    private func island(video: String?, symbol: String, battery: Int?) throws -> DynamicIsland {
        let island = AirPods.island(video: video.map(URL.init(fileURLWithPath:)), symbol: symbol, battery: battery)
        return try JSONDecoder().decode(DynamicIsland.self, from: JSONEncoder().encode(JSONValue(encoding: island)))
    }

    @Test func theIslandIsTheOneTheTypedBuilderProduced() throws {
        #expect(expected.count == 5)
        #expect(try island(video: "/tmp/airpods-pro-2.mp4", symbol: "airpods.pro", battery: 80) == expected["video-80"])
        #expect(try island(video: "/tmp/airpods-pro-2.mp4", symbol: "airpods.pro", battery: 20) == expected["video-20"])
        #expect(try island(video: "/tmp/airpods-pro-2.mp4", symbol: "airpods.pro", battery: nil) == expected["video-unknown"])
        #expect(try island(video: nil, symbol: "airpods", battery: 55) == expected["symbol-55"])
        #expect(try island(video: nil, symbol: "airpods.max", battery: nil) == expected["symbol-unknown"])
    }

    @Test func aLowBatteryTurnsTheRingRed() throws {
        #expect(try island(video: nil, symbol: "airpods", battery: 20).compactTrailing?.tint == "#FF6366")
        #expect(try island(video: nil, symbol: "airpods", battery: 21).compactTrailing?.tint == "#7BF1A8")
    }
}
