// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "NetService",
    products: [
        .library(name: "NetService", targets: ["NetService"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Bouke/Cdns_sd.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "NetService", dependencies: []),
        .target(name: "demo-service", dependencies: ["NetService"]),
        .testTarget(name: "NetServiceTests", dependencies: ["NetService"]),
    ],
    swiftLanguageVersions: [4]
)
