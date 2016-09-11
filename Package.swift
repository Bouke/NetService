import PackageDescription

let package = Package(
    name: "mDNS",
    targets: [
        Target(name: "demo", dependencies: ["mDNS"]),
        Target(name: "mDNS"),
    ],
    dependencies: [
//        .Package(url: "https://github.com/bouke/SwiftSockets.git", versions: Version(0,22,7)..<Version(1,0,0))
    ]
)
