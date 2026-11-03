import Foundation

/// Échecs du playbook, avec un message affichable.
public enum PromptingError: Error, Equatable, Sendable, LocalizedError {
    /// Le fichier, ou son dossier, n'a pas pu être créé.
    case playbookCreationFailed(reason: String)
    /// Le fichier existe mais n'a pas pu être lu.
    case playbookUnreadable(reason: String)
    /// Le fichier n'est pas encodé en UTF-8.
    case playbookNotUTF8
    /// Le playbook dépasse la taille maximale : il ralentirait chaque suggestion.
    case playbookTooLong(characterCount: Int, limit: Int)

    public var errorDescription: String? {
        switch self {
        case .playbookCreationFailed(let reason):
            "Le playbook n'a pas pu être créé : \(reason)"
        case .playbookUnreadable(let reason):
            "Le playbook n'a pas pu être lu : \(reason)"
        case .playbookNotUTF8:
            "Le playbook doit être enregistré en UTF-8."
        case .playbookTooLong(let characterCount, let limit):
            "Le playbook fait \(characterCount.formatted()) caractères, pour \(limit.formatted()) au maximum."
        }
    }
}
