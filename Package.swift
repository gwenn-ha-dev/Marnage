// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Jusant",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "JusantKit", targets: ["JusantKit"]),
        .executable(name: "jusant", targets: ["jusant"]),
    ],
    targets: [
        .target(name: "JusantKit"),
        .executableTarget(name: "jusant", dependencies: ["JusantKit"]),
        .testTarget(name: "JusantKitTests", dependencies: ["JusantKit"]),
    ]
)
