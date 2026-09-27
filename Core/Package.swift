// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HoritaCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HoritaCore", targets: ["HoritaCore"]),
    ],
    targets: [
        .target(
            name: "HoritaCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HoritaCoreTests",
            dependencies: ["HoritaCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
