// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "NetService",
    products: [
        .library(name: "NetService", targets: ["NetService"]),
        .executable(name: "dns-sd", targets: ["dns-sd"])
    ],
    dependencies: [
        .package(url: "https://github.com/Bouke/Cdns_sd.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.3.0"),
    ],
    targets: [
        .target(name: "NetService", dependencies: []),
        .target(name: "dns-sd", dependencies: ["NetService", "Utility"]),
        .testTarget(name: "NetServiceTests", dependencies: ["NetService"]),
    ],
    swiftLanguageVersions: [4]
)
