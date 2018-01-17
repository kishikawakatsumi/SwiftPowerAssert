// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftPowerAssert",
    products: [
        .executable(name: "swift-power-assert", targets: ["SwiftPowerAssert"]),
        .library(name: "PowerAssertCore", type: .dynamic, targets: ["PowerAssertCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "SwiftPowerAssert",
            dependencies: ["PowerAssertCore", "Utility"]
        ),
        .target(
            name: "PowerAssertCore",
            dependencies: ["Utility"]
        ),
        .testTarget(
                name: "SwiftPowerAssertTests",
                dependencies: ["PowerAssertCore"]
        )
    ]
)
