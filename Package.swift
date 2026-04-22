// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "MacControl",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacControl",
            path: "Sources/MacControl"
        )
    ]
)
