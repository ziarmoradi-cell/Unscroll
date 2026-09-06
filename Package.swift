// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "UnscrollCore",
    products: [.library(name: "UnscrollCore", targets: ["UnscrollCore"])],
    targets: [
        .target(name: "UnscrollCore", path: "Core"),
        .testTarget(name: "UnscrollCoreTests", dependencies: ["UnscrollCore"], path: "Tests")
    ]
)
