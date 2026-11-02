import Foundation

/// Échecs de la transcription, avec un message affichable.
public enum TranscriptionError: Error, Equatable, Sendable, LocalizedError {
    /// Les modèles n'ont pas pu être téléchargés ou chargés. Un nouvel appel à `prepare()` réessaie.
    case modelsUnavailable(reason: String)

    public var errorDescription: String? {
        switch self {
        case .modelsUnavailable(let reason):
            "Les modèles de transcription n'ont pas pu être préparés (vérifiez la connexion au premier lancement) : \(reason)"
        }
    }
}
