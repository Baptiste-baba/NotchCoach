// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoachKit",
    platforms: [.macOS(.v15)],
    products: [
        // Produit unique lié par l'app : un nouveau module s'ajoute ici, sans toucher au projet Xcode.
        .library(name: "CoachKit", targets: ["NotchUI", "ClaudeSession"]),
    ],
    targets: [
        .target(name: "NotchUI"),
        .target(name: "ClaudeSession"),
        .testTarget(name: "NotchUITests", dependencies: ["NotchUI"]),
        .testTarget(name: "ClaudeSessionTests", dependencies: ["ClaudeSession"]),
    ]
)
