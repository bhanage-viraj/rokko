// swift-tools-version: 6.2
// RokkoEngine: pure Swift (no SpriteKit / SwiftUI). Round generation, BKT, levels and hints; planner next.
import PackageDescription

let package = Package(
    name: "RokkoEngine",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [.library(name: "RokkoEngine", targets: ["RokkoEngine"])],
    dependencies: [.package(path: "../RokkoContent")],
    targets: [
        .target(name: "RokkoEngine", dependencies: ["RokkoContent"]),
        .testTarget(name: "RoundGeneratorTests", dependencies: ["RokkoEngine", "RokkoContent"]),
        .testTarget(name: "RokkoEngineTests", dependencies: ["RokkoEngine", "RokkoContent"]),
    ]
)
