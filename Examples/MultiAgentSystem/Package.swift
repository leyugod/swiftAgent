// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MultiAgentSystem",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .executable(
            name: "MultiAgentSystem",
            targets: ["MultiAgentSystem"]
        )
    ],
    dependencies: [
        .package(path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "MultiAgentSystem",
            dependencies: [
                .product(name: "SwiftAgent", package: "swiftAgent")
            ],
            path: "Sources/MultiAgentSystem"
        )
    ]
)

