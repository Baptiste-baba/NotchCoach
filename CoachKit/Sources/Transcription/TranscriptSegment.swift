import AudioCapture
import Foundation

/// Segment de transcription d'une prise de parole.
public struct TranscriptSegment: Equatable, Sendable {
    public var speaker: Speaker
    public var text: String
    /// `false` pour un texte provisoire, susceptible de changer. `ParakeetEngine` n'émet que des segments finaux.
    public var isFinal: Bool
    /// Début de la prise de parole, en secondes depuis le début du call.
    public var start: TimeInterval
    /// Fin de la prise de parole, en secondes depuis le début du call.
    public var end: TimeInterval

    public init(speaker: Speaker, text: String, isFinal: Bool, start: TimeInterval, end: TimeInterval) {
        self.speaker = speaker
        self.text = text
        self.isFinal = isFinal
        self.start = start
        self.end = end
    }
}
