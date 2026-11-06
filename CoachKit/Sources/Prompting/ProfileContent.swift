/// Contenu d'un nouveau profil, tel qu'il sera enregistré : écrit par Claude, ou livré avec l'app pour les profils
/// créés au premier lancement.
public struct ProfileContent: Equatable, Sendable {
    /// Rôle de Claude, son objectif, le ton et le format des réponses.
    public var prompt: String
    /// Playbook de départ : ses rubriques, vides.
    public var playbook: String

    public init(prompt: String, playbook: String) {
        self.prompt = prompt
        self.playbook = playbook
    }
}
