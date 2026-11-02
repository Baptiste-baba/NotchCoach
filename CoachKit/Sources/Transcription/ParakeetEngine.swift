import AudioCapture

/// Transcription d'un canal avec FluidAudio : Silero VAD repère la fin de chaque prise de parole, puis
/// Parakeet Ultra transcrit le segment d'un coup sur le Neural Engine.
public actor ParakeetEngine: TranscriptionEngine {
    private let speaker: Speaker
    private let models: ParakeetModels

    public init(speaker: Speaker, models: ParakeetModels) {
        self.speaker = speaker
        self.models = models
    }

    public nonisolated func transcribe(_ audio: AsyncStream<AudioChunk>) -> AsyncStream<TranscriptSegment> {
        fatalError("TODO")
    }
}
