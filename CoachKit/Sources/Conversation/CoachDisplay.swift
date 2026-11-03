/// Ce que la notch doit afficher pendant un call : publié par `CallPipeline` pendant le démarrage du call, puis décidé
/// par `ConversationCoordinator`.
public enum CoachDisplay: Equatable, Sendable {
    /// Notch repliée.
    case hidden
    /// Suggestion de Claude, complète ou encore en train de s'écrire.
    case suggestion(String)
    /// Message d'état : démarrage du call (modèles, lancement de Claude), ou redémarrage de Claude.
    case notice(String)
    /// Échec, affiché en rouge : démarrage du call impossible, Claude n'a pas pu répondre ou il est indisponible.
    case error(String)
}
