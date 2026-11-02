import Foundation

/// Mesure, pour chaque suggestion, le temps passé dans chaque étape depuis la fin de la phrase du prospect
/// jusqu'au premier mot affiché. Logique pure : les instants lui sont fournis, en secondes depuis le début du call.
struct LatencyTracker {
    private struct Pending {
        let requestID: Int
        let speechEnd: TimeInterval
        let segmentReceived: TimeInterval
        var requestSent: TimeInterval?
    }

    /// Seule la réponse à la dernière requête est affichée : une mesure plus ancienne ne sera jamais complète.
    private var pending: Pending?

    /// Une demande vient d'être déclenchée par la phrase du prospect finie à `speechEnd`, reçue à `segmentReceived`.
    mutating func triggered(requestID: Int, speechEnd: TimeInterval, segmentReceived: TimeInterval) {
        pending = Pending(requestID: requestID, speechEnd: speechEnd, segmentReceived: segmentReceived)
    }

    /// La requête vient d'être envoyée à Claude.
    mutating func sent(requestID: Int, at time: TimeInterval) {
        guard pending?.requestID == requestID else { return }
        pending?.requestSent = time
    }

    /// Le premier mot de la suggestion vient d'être affiché. Renvoie la mesure complète de cette requête,
    /// une seule fois.
    mutating func firstWordShown(requestID: Int, at time: TimeInterval) -> LatencyMeasurement? {
        guard let pending, pending.requestID == requestID, let requestSent = pending.requestSent else { return nil }
        self.pending = nil
        return LatencyMeasurement(
            requestID: requestID,
            speechEnd: pending.speechEnd,
            segmentReceived: pending.segmentReceived,
            requestSent: requestSent,
            firstWordShown: time
        )
    }
}
