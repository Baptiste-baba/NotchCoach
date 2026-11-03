import ScreenCaptureKit

/// Capture de l'audio du système avec ScreenCaptureKit, sans celui de l'app : la voix du prospect. ScreenCaptureKit
/// le fournit directement en 16 kHz mono.
actor SystemAudioCapture {
    /// Audio du système. Le flux se termine à l'arrêt.
    nonisolated let chunks: AsyncStream<AudioChunk>
    private let continuation: AsyncStream<AudioChunk>.Continuation

    init() {
        (chunks, continuation) = AsyncStream.makeStream()
    }

    /// Démarre la capture. `origin` : instant zéro du call, en secondes de l'horloge hôte.
    func start(origin: TimeInterval) async throws(AudioCaptureError) {
        fatalError("TODO")
    }

    func stop() async {
        fatalError("TODO")
    }
}
