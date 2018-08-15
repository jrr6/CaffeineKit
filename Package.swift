// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CaffeineKit",
    products: [
        .library(
            name: "CaffeineKit",
            targets: ["CaffeineKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CaffeineKit",
            dependencies: []),
        .testTarget(
            name: "CaffeineKitTests",
            dependencies: ["CaffeineKit"]),
    ]
)
