// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "EventSource",
            targets: ["EventSource"]),
    ],
    dependencies: [
         .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "0.1.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
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
