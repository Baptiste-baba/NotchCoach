/// Source de l'audio d'un call, canal par canal : la vraie capture (`LiveAudioSource`) ou un fichier rejoué
/// (`ReplayAudioSource`). Une source ne sert qu'à un call.
public protocol AudioSource: Actor {
    /// Audio d'un canal, en 16 kHz mono Float32. Le flux se termine à la fin de la source ou à l'arrêt.
    nonisolated func chunks(of speaker: Speaker) -> AsyncStream<AudioChunk>
    /// Coupures survenues pendant le call, que la source n'a pas pu réparer seule. Le flux se termine avec la source.
    nonisolated var failures: AsyncStream<AudioCaptureError> { get }
    /// Démarre la capture ou la lecture. L'instant zéro des morceaux est celui de cet appel.
    func start() async throws(AudioCaptureError)
    /// Arrête la source et termine les deux flux.
    func stop() async
}
