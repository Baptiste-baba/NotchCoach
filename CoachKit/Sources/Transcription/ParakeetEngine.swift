import AudioCapture
import FluidAudio
import Foundation
import os

/// Transcription d'un canal avec FluidAudio : Silero VAD repère la fin de chaque prise de parole, puis
/// Parakeet Ultra transcrit le segment d'un coup sur le Neural Engine.
public actor ParakeetEngine: TranscriptionEngine {
    private let speaker: Speaker
    private let models: ParakeetModels
    /// Vrai entre un morceau coupé par la durée maximale et la fin de la prise de parole.
    private var isInCutSpeech = false

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
        var text = ""
        // Une prise de parole vide ne fait que clore un tour coupé : rien à transcrire.
        if !utterance.samples.isEmpty {
            do {
                text = try await transcribe(utterance, with: asr)
            } catch {
                logger.error("Transcription \(String(describing: self.speaker), privacy: .public) : prise de parole ignorée, \(error.localizedDescription, privacy: .public)")
            }
        }
        let closesCutSpeech = isInCutSpeech && utterance.isComplete
        isInCutSpeech = !utterance.isComplete
        // Sans aucun mot, ou en échec, rien n'est émis, sauf pour clore une prise de parole coupée à 30 s : un segment
        // final vide dit alors au déclencheur que la personne a fini de parler.
        guard !text.isEmpty || closesCutSpeech else { return }
        logger.debug("Segment \(String(describing: self.speaker), privacy: .public) : \(text, privacy: .private)")
        output.yield(TranscriptSegment(
            speaker: speaker,
            text: text,
            isFinal: utterance.isComplete,
            start: utterance.start,
            end: utterance.end
        ))
    }

    /// Texte d'une prise de parole, vide si elle ne contient aucun mot.
    private func transcribe(_ utterance: Utterance, with asr: AsrManager) async throws -> String {
        let signpostState = signposter.beginInterval("Segment STT")
        defer { signposter.endInterval("Segment STT", signpostState) }
        // Chaque prise de parole est indépendante : état de décodage neuf.
        var decoderState = TdtDecoderState.make(decoderLayers: await asr.decoderLayerCount)
        let result = try await asr.transcribe(utterance.samples, decoderState: &decoderState, language: .french)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
