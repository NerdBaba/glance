// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "HotCornerToggle",
    platforms: [.macOS(.v10_15)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "HotCornerToggle",
            dependencies: []
        )
    ]
)