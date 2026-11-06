import Foundation

/// Échecs de l'enregistrement des calls et de leur compte rendu, avec un message affichable.
public enum CallArchiveError: Error, Equatable, Sendable, LocalizedError {
    /// Le fichier du call n'a pas pu être écrit (disque plein, droits…).
    case saveFailed(reason: String)
    /// Le fichier du call n'a pas pu être supprimé.
    case deleteFailed(reason: String)
    /// Claude n'a pas pu écrire le compte rendu (CLI introuvable, réseau coupé, limite d'usage…). Affiché sous « Le
    /// compte rendu n'a pas pu être écrit » : la raison seule suffit.
    case recapFailed(reason: String)
    /// La réponse de Claude ne contient pas de compte rendu lisible.
    case recapInvalid

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let reason):
            "Le call n'a pas pu être enregistré : \(reason)"
        case .deleteFailed(let reason):
            "Le call n'a pas pu être supprimé : \(reason)"
        case .recapFailed(let reason):
            reason
        case .recapInvalid:
            "La réponse de Claude ne contient pas de compte rendu lisible."
        }
    }
}
