// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AeroCue",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AeroCue",
            path: "Sources/AeroCue"
        )
    ]
)
