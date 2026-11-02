import AudioCapture
import Foundation

/// Limite d'une prise de parole repérée par le VAD, en index d'échantillon depuis le début du flux.
enum SpeechBoundary: Equatable, Sendable {
    case start(sampleIndex: Int)
    case end(sampleIndex: Int)
}

/// Prise de parole complète, prête à être transcrite.
struct Utterance: Equatable, Sendable {
    var samples: [Float]
    /// Début et fin, en secondes depuis le début du call.
    var start: TimeInterval
    var end: TimeInterval
}

/// Découpe l'audio d'un canal en prises de parole à partir des limites repérées par le VAD. Logique pure.
struct UtteranceAccumulator {
    /// Audio gardé hors prise de parole : le VAD situe un début jusqu'à un bloc et une marge avant le bloc
    /// où il le détecte.
    var lookbackSampleCount = AudioChunk.sampleRate

    private var buffer: [Float] = []
    /// Index, depuis le début du flux, du premier échantillon de `buffer`.
    private var bufferStart = 0
    /// Début de la prise de parole en cours, s'il y en a une.
    private var speechStart: Int?
    /// Instant du premier échantillon du flux.
    private var streamStartTime: TimeInterval?

    /// Ajoute un morceau d'audio et la limite que le VAD y a repérée. Renvoie la prise de parole qui vient
    /// de se terminer, s'il y en a une.
    mutating func append(_ chunk: AudioChunk, boundary: SpeechBoundary?) -> Utterance? {
        if streamStartTime == nil {
            streamStartTime = chunk.startTime
        }
        buffer += chunk.samples
        var utterance: Utterance?
        switch boundary {
        case .start(let index):
            speechStart = max(index, bufferStart)
        case .end(let index):
            if let start = speechStart {
                let end = min(max(index, start), bufferStart + buffer.count)
                utterance = Utterance(
                    samples: Array(buffer[(start - bufferStart)..<(end - bufferStart)]),
                    start: time(ofSample: start),
                    end: time(ofSample: end)
                )
                speechStart = nil
            }
        case nil:
            break
        }
        trimBuffer()
        return utterance
    }

    /// Pendant une prise de parole, tout est gardé depuis son début ; sinon, seulement les dernières secondes.
    private mutating func trimBuffer() {
        let keepFrom = speechStart ?? (bufferStart + buffer.count - lookbackSampleCount)
        let dropCount = keepFrom - bufferStart
        guard dropCount > 0 else { return }
        buffer.removeFirst(dropCount)
        bufferStart += dropCount
    }

    private func time(ofSample index: Int) -> TimeInterval {
        (streamStartTime ?? 0) + Double(index) / Double(AudioChunk.sampleRate)
    }
}
