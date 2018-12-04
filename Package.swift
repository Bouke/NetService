// swift-tools-version:4.0

import PackageDescription

let package = Package(
  name: "NetService",
  products: [
    .library(name: "NetService", targets: ["NetService"]),
  ],
  dependencies: [
    .package(url: "../Cdns_sd", .branch("master")),
  ],
  targets: [
    .target(name: "NetService", dependencies: []),
    .target(name: "demo-service", dependencies: ["NetService"]),
    .testTarget(name: "NetServiceTests", dependencies: ["NetService"]),
  ],
  swiftLanguageVersions: [4]
)
