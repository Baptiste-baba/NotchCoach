/// Ce que la notch doit afficher pendant un call, décidé par `ConversationCoordinator`.
public enum CoachDisplay: Equatable, Sendable {
    /// Notch repliée.
    case hidden
    /// Suggestion de Claude, complète ou encore en train de s'écrire.
    case suggestion(String)
    /// Message sur l'état de Claude, par exemple pendant un redémarrage.
    case notice(String)
    /// Échec, affiché en rouge : Claude n'a pas pu répondre, ou il est indisponible.
    case error(String)
}
