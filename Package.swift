import PackageDescription

let package = Package(
    name: "mDNS",
    targets: [
        Target(name: "demo", dependencies: ["NetService"]),
        Target(name: "NetService", dependencies: ["Cifaddrs", "DNS"])
    ]
)
