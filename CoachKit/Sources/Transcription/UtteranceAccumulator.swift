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
    /// Ajoute un morceau d'audio et la limite que le VAD y a repérée. Renvoie la prise de parole qui vient
    /// de se terminer, s'il y en a une.
    mutating func append(_ chunk: AudioChunk, boundary: SpeechBoundary?) -> Utterance? {
        fatalError("TODO")
    }
}
