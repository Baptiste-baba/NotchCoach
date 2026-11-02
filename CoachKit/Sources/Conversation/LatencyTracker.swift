import Foundation

/// Mesure, pour chaque suggestion, le temps passé dans chaque étape depuis la fin de la phrase du prospect
/// jusqu'au premier mot affiché. Logique pure : les instants lui sont fournis, en secondes depuis le début du call.
struct LatencyTracker {
    /// Une demande vient d'être déclenchée par la phrase du prospect finie à `speechEnd`, reçue à `segmentReceived`.
    mutating func triggered(requestID: Int, speechEnd: TimeInterval, segmentReceived: TimeInterval) {
        fatalError("TODO")
    }

    /// La requête vient d'être envoyée à Claude.
    mutating func sent(requestID: Int, at time: TimeInterval) {
        fatalError("TODO")
    }

    /// Le premier mot de la suggestion vient d'être affiché. Renvoie la mesure complète de cette requête,
    /// une seule fois.
    mutating func firstWordShown(requestID: Int, at time: TimeInterval) -> LatencyMeasurement? {
        fatalError("TODO")
    }
}
