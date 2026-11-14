// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Niche",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NicheNowPlaying", type: .dynamic, targets: ["NicheNowPlaying"])
    ],
    targets: [
        .target(name: "NicheKit", path: "Sources/NicheKit"),
        .target(name: "NowPlayingWire", path: "Sources/NowPlayingWire"),
        .target(name: "NicheNowPlaying", dependencies: ["NowPlayingWire"], path: "Sources/NicheNowPlaying"),
        .executableTarget(name: "Niche", dependencies: ["NicheKit", "NowPlayingWire"], path: "Sources/Niche"),
        .executableTarget(name: "NicheCLI", dependencies: ["NicheKit"], path: "Sources/NicheCLI"),
        .testTarget(name: "NicheKitTests", dependencies: ["NicheKit", "NicheCLI"], path: "Tests/NicheKitTests"),
        .testTarget(
            name: "NicheTests",
            dependencies: ["Niche", "NicheKit", "NicheNowPlaying", "NowPlayingWire"],
            path: "Tests/NicheTests",
            exclude: ["Fixtures"]
        )
    ]
)
