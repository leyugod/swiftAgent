// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TravelAssistant",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .executable(
            name: "TravelAssistant",
            targets: ["TravelAssistant"]
        )
    ],
    dependencies: [
        .package(path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "TravelAssistant",
            dependencies: [
                .product(name: "SwiftAgent", package: "swiftAgent")
            ],
            path: "Sources/TravelAssistant"
        )
    ]
)

