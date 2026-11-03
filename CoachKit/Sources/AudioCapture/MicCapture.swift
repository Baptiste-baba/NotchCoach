import AVFoundation

/// Capture du micro avec `AVAudioEngine` : la voix de l'utilisateur, convertie en 16 kHz mono.
actor MicCapture {
    /// Audio du micro. Le flux se termine à l'arrêt.
    nonisolated let chunks: AsyncStream<AudioChunk>
    private let continuation: AsyncStream<AudioChunk>.Continuation

    init() {
        (chunks, continuation) = AsyncStream.makeStream()
    }

    /// Démarre la capture. `origin` : instant zéro du call, en secondes de l'horloge hôte.
    func start(origin: TimeInterval) throws(AudioCaptureError) {
        fatalError("TODO")
    }

    func stop() {
        fatalError("TODO")
    }
}
