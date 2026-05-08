// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RemoteDockCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "RemoteDockCore",
            targets: ["RemoteDockCore"]
        )
    ],
    targets: [
        .target(
            name: "RemoteDockCore"
        )
    ]
)
