import AudioCapture
import FluidAudio
import Foundation
import os

private let logger = Logger(subsystem: "io.github.baptiste-baba.NotchCoach", category: "Transcription")
private let signposter = OSSignposter(subsystem: "io.github.baptiste-baba.NotchCoach", category: "Transcription")

/// Transcription d'un canal avec FluidAudio : Silero VAD repère la fin de chaque prise de parole, puis
/// Parakeet Ultra transcrit le segment d'un coup sur le Neural Engine.
public actor ParakeetEngine: TranscriptionEngine {
    /// Taille de bloc traitée par le VAD de FluidAudio : 4096 échantillons, soit 256 ms.
    private static let vadBlockSize = VadManager.chunkSize

    private let speaker: Speaker
    private let models: ParakeetModels

    public init(speaker: Speaker, models: ParakeetModels) {
        self.speaker = speaker
        self.models = models
    }

    public nonisolated func transcribe(_ audio: AsyncStream<AudioChunk>) -> AsyncStream<TranscriptSegment> {
        let (segments, continuation) = AsyncStream<TranscriptSegment>.makeStream()
        let task = Task { await run(audio, output: continuation) }
        continuation.onTermination = { _ in task.cancel() }
        return segments
    }

    private func run(_ audio: AsyncStream<AudioChunk>, output: AsyncStream<TranscriptSegment>.Continuation) async {
        defer { output.finish() }
        do {
            let models = try await self.models.loaded()
            var vadState = await models.vad.makeStreamState()
            var accumulator = UtteranceAccumulator()
            // Les morceaux reçus sont regroupés en blocs de la taille attendue par le VAD.
            var pending: [Float] = []
            var pendingStart: TimeInterval = 0
            for await chunk in audio {
                if pending.isEmpty {
                    pendingStart = chunk.startTime
                }
                pending += chunk.samples
                while pending.count >= Self.vadBlockSize {
                    let block = AudioChunk(samples: Array(pending.prefix(Self.vadBlockSize)), startTime: pendingStart)
                    pending.removeFirst(Self.vadBlockSize)
                    pendingStart += Double(Self.vadBlockSize) / Double(AudioChunk.sampleRate)

                    let result = try await models.vad.processStreamingChunk(block.samples, state: vadState)
                    vadState = result.state
                    let boundary = result.event.map { event -> SpeechBoundary in
                        switch event.kind {
                        case .speechStart: .start(sampleIndex: event.sampleIndex)
                        case .speechEnd: .end(sampleIndex: event.sampleIndex)
                        }
                    }
                    if let utterance = accumulator.append(block, boundary: boundary),
                       let segment = try await transcribe(utterance, with: models.asr)
                    {
                        output.yield(segment)
                    }
                }
            }
        } catch {
            logger.error("Transcription \(String(describing: self.speaker), privacy: .public) interrompue : \(error.localizedDescription, privacy: .public)")
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
        return TranscriptSegment(speaker: speaker, text: text, isFinal: true, start: utterance.start, end: utterance.end)
    }
}
