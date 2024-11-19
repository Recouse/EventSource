// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "EventSource",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "EventSource",
            targets: ["EventSource"]),
    ],
    targets: [
        .target(
            name: "EventSource",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]),
        .testTarget(
            name: "EventSourceTests",
            dependencies: ["EventSource"]),
    ]
)
