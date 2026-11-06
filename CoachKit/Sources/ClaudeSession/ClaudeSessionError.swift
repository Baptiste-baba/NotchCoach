import Foundation

/// Échecs du lancement du CLI, et d'une requête unique (`ClaudeCompletion`), avec un message affichable.
public enum ClaudeSessionError: Error, Equatable, Sendable, LocalizedError {
    /// `command -v claude` n'a renvoyé aucun chemin absolu dans le shell de connexion.
    case binaryNotFound
    /// Le chemin, forcé dans les réglages ou résolu, ne désigne pas un fichier exécutable.
    case binaryNotExecutable(path: String)
    /// Le process n'a pas pu être lancé.
    case launchFailed(reason: String)
    /// Requête unique : Claude a répondu par une erreur (réseau coupé, limite d'usage atteinte…).
    case responseFailed(message: String)
    /// Requête unique : le process s'est arrêté sans renvoyer de réponse lisible.
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            "Le CLI claude est introuvable. Installez Claude Code ou indiquez son chemin dans les réglages."
        case .binaryNotExecutable(let path):
            "\(path) n'est pas un exécutable."
        case .launchFailed(let reason):
            "Le CLI claude n'a pas pu être lancé : \(reason)"
        case .responseFailed(let message):
            "Claude a renvoyé une erreur : \(message)"
        case .invalidResponse:
            "Le CLI claude s'est arrêté sans renvoyer de réponse."
        }
    }
}
