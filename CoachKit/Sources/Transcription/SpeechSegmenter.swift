import AudioCapture
import FluidAudio
import Foundation
import os

/// Découpe l'audio d'un canal en prises de parole : regroupe les morceaux reçus en blocs de la taille attendue
/// par le VAD, interroge le VAD sur chaque bloc et accumule l'audio entre les limites qu'il repère.
struct SpeechSegmenter {
    /// Interroge le VAD sur un bloc. `ParakeetEngine` y branche le `VadManager` de FluidAudio, les tests un faux VAD.
    typealias Detector = @Sendable (_ block: [Float], _ state: VadStreamState) async throws -> VadStreamResult

    private let speaker: Speaker
    private let blockSize: Int
    private let detect: Detector
    private var vadState = VadStreamState.initial()
    private var accumulator: UtteranceAccumulator
    private var pending: [Float] = []
    private var pendingStart: TimeInterval = 0

    init(
        speaker: Speaker,
        blockSize: Int = VadManager.chunkSize,
        accumulator: UtteranceAccumulator = UtteranceAccumulator(),
        detect: @escaping Detector
    ) {
        self.speaker = speaker
        self.blockSize = blockSize
        self.accumulator = accumulator
        self.detect = detect
    }

    /// Ajoute un morceau d'audio et renvoie les prises de parole qu'il termine. Une erreur du VAD sur un bloc est
    /// journalisée et ignorée.
    mutating func append(_ chunk: AudioChunk) async -> [Utterance] {
        if pending.isEmpty {
            pendingStart = chunk.startTime
        }
        pending += chunk.samples
        var utterances: [Utterance] = []
        while pending.count >= blockSize {
            let block = AudioChunk(samples: Array(pending.prefix(blockSize)), startTime: pendingStart)
            pending.removeFirst(blockSize)
            pendingStart += Double(blockSize) / Double(AudioChunk.sampleRate)

            var boundary: SpeechBoundary?
            do {
                let result = try await detect(block.samples, vadState)
                vadState = result.state
                boundary = result.event.map { event in
                    switch event.kind {
                    case .speechStart: .start(sampleIndex: event.sampleIndex)
                    case .speechEnd: .end(sampleIndex: event.sampleIndex)
                    }
                }
            } catch {
                // FluidAudio n'avance son compteur d'échantillons que sur un bloc traité : on l'avance à sa place,
                // sinon toutes les limites suivantes arriveraient un bloc trop tôt. Le bloc reste dans l'accumulateur,
                // sans limite repérée, pour que l'audio garde sa continuité.
                vadState.processedSamples += block.samples.count
                let speaker = speaker
                logger.error("VAD \(String(describing: speaker), privacy: .public) : bloc ignoré, \(error.localizedDescription, privacy: .public)")
            }
            if let utterance = accumulator.append(block, boundary: boundary) {
                utterances.append(utterance)
            }
        }
        return utterances
    }

    /// Fin du flux (fin du replay, audio coupé) : renvoie la prise de parole en cours, coupée là où l'audio s'arrête.
    mutating func finish() -> [Utterance] {
        var utterances: [Utterance] = []
        // Le dernier morceau, plus court qu'un bloc, peut faire dépasser la durée maximale : la prise de parole
        // coupée là est gardée, et `finish()` renvoie ensuite le reste.
        if !pending.isEmpty, let utterance = accumulator.append(AudioChunk(samples: pending, startTime: pendingStart), boundary: nil) {
            utterances.append(utterance)
        }
        pending = []
        // Après un morceau coupé, le tour de parole est toujours clos par une prise de parole complète, même vide.
        if let utterance = accumulator.finish() {
            utterances.append(utterance)
        }
        return utterances
    }
}
