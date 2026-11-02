import AudioCapture

/// Moteur de transcription d'un canal : reçoit l'audio, émet des segments de transcription.
/// Une instance par canal, qui connaît son `Speaker`. Implémenté par `ParakeetEngine`, et par un mock dans les tests.
public protocol TranscriptionEngine: Sendable {
    /// Transcrit l'audio jusqu'à la fin du flux. Le flux de segments se termine après le dernier segment.
    func transcribe(_ audio: AsyncStream<AudioChunk>) -> AsyncStream<TranscriptSegment>
}
