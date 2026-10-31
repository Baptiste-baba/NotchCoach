/// Possède le process `claude` pour toute la durée d'un call : lancement, envoi des requêtes,
/// streaming des réponses, abandon des réponses obsolètes et redémarrage automatique.
public actor ClaudeSession: LLMSession {
    public init() {}
}
