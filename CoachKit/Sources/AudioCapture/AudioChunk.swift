import Foundation

/// Morceau d'audio d'un canal, au format de sortie du module : 16 kHz mono Float32.
public struct AudioChunk: Equatable, Sendable {
    public static let sampleRate = 16_000

    public var samples: [Float]
    /// Instant du premier échantillon, en secondes depuis le début du call.
    public var startTime: TimeInterval

    public init(samples: [Float], startTime: TimeInterval) {
        self.samples = samples
        self.startTime = startTime
    }
}
