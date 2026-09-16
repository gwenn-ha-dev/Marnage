// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Marnage",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "MarnageKit", targets: ["MarnageKit"]),
        .executable(name: "marnage", targets: ["marnage"]),
    ],
    targets: [
        .target(name: "MarnageKit"),
        .executableTarget(name: "marnage", dependencies: ["MarnageKit"]),
        .testTarget(name: "MarnageKitTests", dependencies: ["MarnageKit"]),
    ]
)
