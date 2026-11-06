import Foundation

/// Échecs des profils (nom, prompt, playbook) et de leur génération, avec un message affichable.
public enum PromptingError: Error, Equatable, Sendable, LocalizedError {
    /// Le fichier du playbook, ou son dossier, n'a pas pu être créé.
    case playbookCreationFailed(reason: String)
    /// Le fichier existe mais n'a pas pu être lu.
    case playbookUnreadable(reason: String)
    /// Le fichier n'est pas encodé en UTF-8.
    case playbookNotUTF8
    /// Le playbook dépasse la taille maximale : il ralentirait chaque suggestion.
    case playbookTooLong(characterCount: Int, limit: Int)

    /// Le prompt du profil n'a pas pu être lu (supprimé, droits d'accès…).
    case promptUnreadable(profile: String, reason: String)
    /// Le prompt du profil n'est pas encodé en UTF-8.
    case promptNotUTF8(profile: String)
    /// Le prompt du profil ne contient que des espaces ou des lignes vides.
    case promptEmpty(profile: String)
    /// Le prompt du profil dépasse la taille maximale : il ralentirait chaque suggestion.
    case promptTooLong(profile: String, characterCount: Int, limit: Int)

    /// Le nom ne peut pas devenir celui d'un dossier : vide, trop long, avec « / », « : » ou un retour à la ligne, ou
    /// commençant par un point (dossier caché).
    case invalidProfileName(String)
    /// Un profil, ou un dossier, porte déjà ce nom.
    case profileAlreadyExists(String)
    /// Le dossier ou les fichiers du profil n'ont pas pu être écrits.
    case profileCreationFailed(reason: String)

    /// Claude n'a pas pu écrire le profil (CLI introuvable, réseau coupé, limite d'usage atteinte…).
    case generationFailed(reason: String)
    /// La réponse de Claude ne contient pas de prompt utilisable.
    case generationInvalid
    /// La génération a été annulée : rien à montrer.
    case generationCancelled

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
        case .promptUnreadable(let profile, let reason):
            "Le prompt du profil « \(profile) » n'a pas pu être lu : \(reason)"
        case .promptNotUTF8(let profile):
            "Le prompt du profil « \(profile) » doit être enregistré en UTF-8."
        case .promptEmpty(let profile):
            "Le prompt du profil « \(profile) » est vide."
        case .promptTooLong(let profile, let characterCount, let limit):
            "Le prompt du profil « \(profile) » fait \(characterCount.formatted()) caractères, pour \(limit.formatted()) au maximum."
        case .invalidProfileName(let name):
            name.trimmingCharacters(in: .whitespaces).isEmpty
                ? "Donne un nom au profil."
                : "« \(name) » ne peut pas servir de nom : 50 caractères au plus, sans « / » ni « : », et sans point au début."
        case .profileAlreadyExists(let name):
            "Un profil « \(name) » existe déjà."
        case .profileCreationFailed(let reason):
            "Le profil n'a pas pu être enregistré : \(reason)"
        case .generationFailed(let reason):
            "Claude n'a pas pu écrire le profil. \(reason)"
        case .generationInvalid:
            "La réponse de Claude ne contient pas de prompt utilisable. Réessaie, ou précise la description."
        case .generationCancelled:
            "Création du profil annulée."
        }
    }
}
