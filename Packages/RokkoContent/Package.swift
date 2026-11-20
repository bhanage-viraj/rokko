// swift-tools-version: 6.2
// RokkoContent: Codable models for the lesson content (pool, voice lines, engine config). No UI imports.
import PackageDescription

let package = Package(
    name: "RokkoContent",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [.library(name: "RokkoContent", targets: ["RokkoContent"])],
    targets: [
        .target(name: "RokkoContent"),
        .testTarget(name: "ContentValidationTests", dependencies: ["RokkoContent"]),
    ]
)
