/// Playbook commercial de l'utilisateur : offre, cible, pricing, objections fréquentes et réponses validées.
/// Ajouté au system prompt de Claude au lancement de chaque session.
public struct Playbook: Equatable, Sendable {
    /// Contenu Markdown, tel que l'utilisateur l'a écrit.
    public var markdown: String

    public init(markdown: String) {
        self.markdown = markdown
    }
}
