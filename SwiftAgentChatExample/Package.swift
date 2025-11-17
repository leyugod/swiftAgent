// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftAgentChatExample",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SwiftAgentChatExample",
            targets: ["SwiftAgentChatExample"]
        )
    ],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .executableTarget(
            name: "SwiftAgentChatExample",
            dependencies: [
                .product(name: "SwiftAgent", package: "swiftAgent")
            ],
            path: "SwiftAgentChat"
        )
    ]
)

