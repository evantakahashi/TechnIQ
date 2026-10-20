// swift-tools-version:5.9
// Mac harness for the camera-drill counting core. JuggleCore's sources are symlinks into
// TechnIQ/CameraDrills/{Core,Vision} so the app and the harness run the same code.
import PackageDescription

let package = Package(
    name: "juggle-harness",
    platforms: [.macOS(.v14)],
    targets: [
        // App code is internal; the harness reaches it via @testable, so build it testable in release too.
        .target(name: "JuggleCore", swiftSettings: [.unsafeFlags(["-enable-testing"])]),
        .executableTarget(name: "juggle-harness", dependencies: ["JuggleCore"]),
        .testTarget(name: "JuggleCoreTests", dependencies: ["JuggleCore"]),
    ]
)
