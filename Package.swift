import PackageDescription

let package = Package(
    name: "mDNS",
    targets: [
        Target(name: "demo", dependencies: ["NetService"]),
        Target(name: "NetService", dependencies: ["Cifaddrs", "DNS"])
    ],
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/BlueSocket", majorVersion: 0, minor: 12)
    ]
)
