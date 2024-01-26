// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "EventSource",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "EventSource",
            targets: ["EventSource"]),
    ],
    dependencies: [
         .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "EventSource",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ]),
        .testTarget(
            name: "EventSourceTests",
            dependencies: ["EventSource"]),
    ]
)
