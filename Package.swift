// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Niche",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NicheKit", path: "Sources/NicheKit"),
        .executableTarget(name: "Niche", dependencies: ["NicheKit"], path: "Sources/Niche"),
        .executableTarget(name: "NicheCLI", dependencies: ["NicheKit"], path: "Sources/NicheCLI"),
        .testTarget(name: "NicheKitTests", dependencies: ["NicheKit", "NicheCLI"], path: "Tests/NicheKitTests"),
        .testTarget(
            name: "NicheTests",
            dependencies: ["Niche", "NicheKit"],
            path: "Tests/NicheTests",
            exclude: ["Fixtures"]
        )
    ]
)
