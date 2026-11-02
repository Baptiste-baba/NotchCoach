import Foundation

/// Mode replay : lit un fichier stéréo à vitesse réelle à la place d'un vrai call (canal gauche = moi,
/// canal droit = prospect) et fournit chaque canal en 16 kHz mono Float32, comme la capture réelle.
public actor ReplayAudioSource {
    private let file: URL
    private let meChunks: AsyncStream<AudioChunk>
    private let meContinuation: AsyncStream<AudioChunk>.Continuation
    private let prospectChunks: AsyncStream<AudioChunk>
    private let prospectContinuation: AsyncStream<AudioChunk>.Continuation

    public init(file: URL) {
        self.file = file
        (meChunks, meContinuation) = AsyncStream.makeStream()
        (prospectChunks, prospectContinuation) = AsyncStream.makeStream()
    }

    /// Audio d'un canal. Le flux se termine à la fin du fichier ou à l'arrêt.
    public nonisolated func chunks(of speaker: Speaker) -> AsyncStream<AudioChunk> {
        switch speaker {
        case .me: meChunks
        case .prospect: prospectChunks
        }
    }

    /// Ouvre le fichier et commence la lecture à vitesse réelle.
    public func start() throws {
        fatalError("TODO")
    }

    /// Arrête la lecture et termine les deux flux.
    public func stop() {
        fatalError("TODO")
    }
}
