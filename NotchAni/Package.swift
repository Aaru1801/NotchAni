// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotchAni",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NotchAni",
            path: "Sources/NotchAni"
        )
    ]
)
