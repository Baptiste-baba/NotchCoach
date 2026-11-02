import Transcription

/// Demande de suggestion décidée par `TriggerDetector`.
public struct Trigger: Equatable, Sendable {
    /// Identifiant croissant, repris par la requête envoyée à Claude : une réponse à un déclenchement plus ancien
    /// est obsolète.
    public var requestID: Int
    /// Phrase du prospect qui a déclenché la demande. Sa fin sert de point de départ pour mesurer la latence
    /// jusqu'au premier mot affiché.
    public var segment: TranscriptSegment

    public init(requestID: Int, segment: TranscriptSegment) {
        self.requestID = requestID
        self.segment = segment
    }
}
