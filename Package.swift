// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MicKeeperCore",
    platforms: [.macOS(.v15)],
    products: [.library(name: "MicKeeperCore", targets: ["MicKeeperCore"])],
    targets: [
        .target(name: "MicKeeperCore"),
        .testTarget(name: "MicKeeperCoreTests", dependencies: ["MicKeeperCore"])
    ]
)
