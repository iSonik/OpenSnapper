// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OpenSnapper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "OpenSnapper",
            targets: ["OpenSnapper"]
        )
    ],
    targets: [
        .executableTarget(
            name: "OpenSnapper",
            path: "Sources/OpenSnapper"
        )
    ]
)
