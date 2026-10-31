// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoachKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "NotchUI", targets: ["NotchUI"]),
    ],
    targets: [
        .target(name: "NotchUI"),
        .testTarget(name: "NotchUITests", dependencies: ["NotchUI"]),
    ]
)
