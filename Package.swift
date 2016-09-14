import PackageDescription

let package = Package(
    name: "mDNS",
    targets: [
        Target(name: "demo", dependencies: ["mDNS"]),
        Target(name: "mDNS"),
    ]
)
