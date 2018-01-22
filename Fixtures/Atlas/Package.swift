// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Atlas",
    products: [
        .library(name: "Atlas", targets: ["Atlas"])
    ],
    targets: [
        .target(name: "Atlas", dependencies: []),
        .testTarget(name: "AtlasTests", dependencies: ["Atlas"])
    ]
)
