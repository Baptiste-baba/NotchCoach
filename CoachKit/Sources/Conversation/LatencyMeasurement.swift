import Foundation

/// Instants clés d'une suggestion, en secondes depuis le début du call : de la fin de la phrase du prospect
/// au premier mot affiché.
struct LatencyMeasurement: Equatable, Sendable {
    let requestID: Int
    /// Fin de la phrase du prospect, telle que la situe le VAD (marge de 0,1 s comprise).
    let speechEnd: TimeInterval
    /// Arrivée du segment transcrit : après l'attente du silence par le VAD, puis la transcription.
    let segmentReceived: TimeInterval
    /// Envoi de la requête à Claude.
    let requestSent: TimeInterval
    /// Premier mot de la suggestion affiché.
    let firstWordShown: TimeInterval
}
