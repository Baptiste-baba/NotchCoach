import AudioCapture
import FluidAudio
import Foundation
import os

/// Transcription d'un canal avec FluidAudio : Silero VAD repère la fin de chaque prise de parole, puis
/// Parakeet Ultra transcrit le segment d'un coup sur le Neural Engine.
public actor ParakeetEngine: TranscriptionEngine {
    private let speaker: Speaker
    private let models: ParakeetModels

    public init(speaker: Speaker, models: ParakeetModels) {
        self.speaker = speaker
        self.models = models
    }

    /// Une erreur sur un bloc ou une prise de parole est journalisée et ignorée : la transcription du canal continue.
    /// Si les modèles ne peuvent pas être préparés, le flux de segments se termine aussitôt.
    public nonisolated func transcribe(_ audio: AsyncStream<AudioChunk>) -> AsyncStream<TranscriptSegment> {
        let (segments, continuation) = AsyncStream<TranscriptSegment>.makeStream()
        let task = Task { await run(audio, output: continuation) }
        continuation.onTermination = { _ in task.cancel() }
        return segments
    }

    private func run(_ audio: AsyncStream<AudioChunk>, output: AsyncStream<TranscriptSegment>.Continuation) async {
        defer { output.finish() }
        let models: LoadedModels
        do {
            models = try await self.models.loaded()
        } catch {
            return
        }
        let vad = models.vad
        var segmenter = SpeechSegmenter(speaker: speaker) { block, state in
            try await vad.processStreamingChunk(block, state: state)
        }
        for await chunk in audio {
            for utterance in await segmenter.append(chunk) {
                await emit(utterance, with: models.asr, to: output)
            }
        }
        guard !Task.isCancelled else { return }
        for utterance in segmenter.finish() {
            await emit(utterance, with: models.asr, to: output)
        }
    }

    private func emit(
        _ utterance: Utterance,
        with asr: AsrManager,
        to output: AsyncStream<TranscriptSegment>.Continuation
    ) async {
        do {
            if let segment = try await transcribe(utterance, with: asr) {
                output.yield(segment)
            }
        } catch {
            logger.error("Transcription \(String(describing: self.speaker), privacy: .public) : prise de parole ignorée, \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Transcrit une prise de parole, ou renvoie `nil` si elle ne contient aucun mot.
    private func transcribe(_ utterance: Utterance, with asr: AsrManager) async throws -> TranscriptSegment? {
        let signpostState = signposter.beginInterval("Segment STT")
        defer { signposter.endInterval("Segment STT", signpostState) }
        // Chaque prise de parole est indépendante : état de décodage neuf.
        var decoderState = TdtDecoderState.make(decoderLayers: await asr.decoderLayerCount)
        let result = try await asr.transcribe(utterance.samples, decoderState: &decoderState, language: .french)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        logger.debug("Segment \(String(describing: self.speaker), privacy: .public) : \(text, privacy: .private)")
        return TranscriptSegment(
            speaker: speaker,
            text: text,
            isFinal: utterance.isComplete,
            start: utterance.start,
            end: utterance.end
        )
    }
}
