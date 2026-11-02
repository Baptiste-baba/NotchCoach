import AudioCapture
import Foundation
import Transcription

/// Décide quand demander une suggestion à Claude : le prospect vient de finir de parler, et aucune suggestion
/// n'a été demandée récemment. Logique pure, sans I/O ni horloge : le temps vient des segments eux-mêmes.
public struct TriggerDetector {
    /// Délai minimal entre deux suggestions, mesuré entre les fins des phrases du prospect qui les ont déclenchées.
    public var cooldown: TimeInterval

    private var nextRequestID = 1
    /// Fin de la phrase qui a déclenché la dernière suggestion.
    private var lastTriggerEnd: TimeInterval?

    public init(cooldown: TimeInterval = 5) {
        self.cooldown = cooldown
    }

    /// Reçoit un segment de l'un ou l'autre canal. Renvoie un déclenchement pour une phrase finale du prospect,
    /// hors délai anti-spam ; sinon `nil`.
    /// - Un segment final sans texte déclenche aussi : il clôt une prise de parole coupée en morceaux, dont le texte
    ///   est déjà arrivé.
    /// - Une phrase qui finit avant celle du dernier déclenchement arrive en retard : elle ne déclenche pas.
    public mutating func receive(_ segment: TranscriptSegment) -> Trigger? {
        // Les 0,75 s de silence qu'attend le VAD avant de clore une prise de parole font office de détection
        // de fin de prise de parole : pas d'attente supplémentaire ici.
        guard segment.speaker == .prospect, segment.isFinal else { return nil }
        if let lastTriggerEnd, segment.end - lastTriggerEnd < cooldown {
            return nil
        }
        lastTriggerEnd = segment.end
        let trigger = Trigger(requestID: nextRequestID, segment: segment)
        nextRequestID += 1
        return trigger
    }
}
