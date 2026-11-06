/// Playbook d'un profil : les informations de l'utilisateur (offre, pricing et objections pour la vente, parcours et
/// projets pour un entretien). Ajouté au system prompt de Claude au lancement de chaque session.
public struct Playbook: Equatable, Sendable {
    /// Contenu Markdown, tel que l'utilisateur l'a écrit.
    public var markdown: String

    public init(markdown: String) {
        self.markdown = markdown
    }
}
