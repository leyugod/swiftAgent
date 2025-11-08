// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeepSeekExample",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "DeepSeekExample",
            dependencies: [
                .product(name: "SwiftAgent", package: "swiftAgent")
            ],
            path: "Sources"
        )
    ]
)

