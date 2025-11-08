// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SimpleAgent",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .executable(
            name: "SimpleAgent",
            targets: ["SimpleAgent"]
        )
    ],
    dependencies: [
        .package(path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "SimpleAgent",
            dependencies: [
                .product(name: "SwiftAgent", package: "swiftAgent")
            ],
            path: "Sources/SimpleAgent"
        )
    ]
)

