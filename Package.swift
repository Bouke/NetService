// swift-tools-version:4.0

import PackageDescription

let package = Package(
  name: "NetService",
  products: [
    .library(name: "Cifaddrs", targets: ["Cifaddrs"]),
    .library(name: "NetService", targets: ["NetService"]),
  ],
  dependencies: [
    .package(url: "https://github.com/Bouke/DNS.git", from: "1.1.0"),
    .package(url: "https://github.com/IBM-Swift/BlueSocket.git", from: "1.0.0"),
    .package(url: "../Cdns_sd", .branch("master")),
  ],
  targets: [
    .target(name: "Cifaddrs"),
    .target(name: "NetService", dependencies: ["Cifaddrs", "DNS", "Socket"]),
    .target(name: "demo-service", dependencies: ["NetService"]),
    .testTarget(name: "NetServiceTests", dependencies: ["NetService"]),
  ],
  swiftLanguageVersions: [4]
)
