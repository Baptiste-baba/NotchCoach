import Foundation
import Transcription

/// Décide quand demander une suggestion à Claude : le prospect vient de finir de parler, et aucune suggestion
/// n'a été demandée récemment. Logique pure, sans I/O ni horloge : le temps vient des segments eux-mêmes.
public struct TriggerDetector {
    /// Délai minimal entre deux suggestions, mesuré entre les fins des phrases du prospect qui les ont déclenchées.
    public var cooldown: TimeInterval

    public init(cooldown: TimeInterval = 5) {
        self.cooldown = cooldown
    }

    /// Reçoit un segment de l'un ou l'autre canal. Renvoie un déclenchement pour une phrase finale du prospect,
    /// hors délai anti-spam ; sinon `nil`.
    public mutating func receive(_ segment: TranscriptSegment) -> Trigger? {
        fatalError("TODO")
    }
}
