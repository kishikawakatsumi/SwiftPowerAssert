// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftPowerAssert",
    products: [
        .executable(name: "swift-power-assert", targets: ["SwiftPowerAssert"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/kylef/Commander.git",
            from: "0.0.0"
        )
    ],
    targets: [
        .target(
            name: "SwiftPowerAssert",
            dependencies: ["SwiftPowerAssertCore", "Commander"]
        ),
        .target(
            name: "SwiftPowerAssertCore"
        ),
        .testTarget(
                name: "SwiftPowerAssertTests",
                dependencies: ["SwiftPowerAssertCore"]
        )
    ]
)
