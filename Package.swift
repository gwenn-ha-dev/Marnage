// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Marees",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "MareeKit", targets: ["MareeKit"]),
        .executable(name: "maree", targets: ["maree"]),
    ],
    targets: [
        .target(name: "MareeKit"),
        .executableTarget(name: "maree", dependencies: ["MareeKit"]),
        .testTarget(name: "MareeKitTests", dependencies: ["MareeKit"]),
    ]
)
