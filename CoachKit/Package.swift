// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CoachKit",
    platforms: [.macOS(.v15)],
    products: [
        // Produit unique lié par l'app : un nouveau module s'ajoute ici, sans toucher au projet Xcode.
        .library(name: "CoachKit", targets: ["NotchUI", "ClaudeSession", "AudioCapture", "Transcription", "Conversation"]),
    ],
    dependencies: [
        // Version exacte. `traits: []` : transcription et détection de voix seulement, sans synthèse vocale,
        // diarisation ni le binaire Rust de normalisation de texte.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.18.0", traits: []),
    ],
    targets: [
        .target(name: "NotchUI"),
        .target(name: "ClaudeSession"),
        .target(name: "AudioCapture"),
        .target(
            name: "Transcription",
            dependencies: ["AudioCapture", .product(name: "FluidAudio", package: "FluidAudio")]
        ),
        .target(name: "Conversation", dependencies: ["AudioCapture", "Transcription"]),
        .testTarget(name: "NotchUITests", dependencies: ["NotchUI"]),
        .testTarget(name: "ClaudeSessionTests", dependencies: ["ClaudeSession"]),
        .testTarget(name: "AudioCaptureTests", dependencies: ["AudioCapture"]),
        .testTarget(
            name: "TranscriptionTests",
            dependencies: ["Transcription", .product(name: "FluidAudio", package: "FluidAudio")]
        ),
        .testTarget(name: "ConversationTests", dependencies: ["Conversation", "AudioCapture", "Transcription"]),
    ]
)
