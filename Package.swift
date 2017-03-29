import PackageDescription

let package = Package(
    name: "NetService",
    targets: [
        Target(name: "NetService", dependencies: ["Cifaddrs"])
    ],
    dependencies: [
        .Package(url: "https://github.com/Bouke/DNS.git", majorVersion: 0, minor: 1),
        .Package(url: "https://github.com/IBM-Swift/BlueSocket.git", majorVersion: 0, minor: 12)
    ]
)
