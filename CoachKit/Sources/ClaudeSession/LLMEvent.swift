/// Ce que la session émet, uniquement pour la requête la plus récente.
public enum LLMEvent: Equatable, Sendable {
    /// Nouveau morceau de texte de la réponse, à afficher à la suite des précédents.
    case delta(requestID: Int, text: String)
    /// La réponse est complète.
    case finished(requestID: Int)
    /// La requête n'aura pas de réponse : session indisponible, process mort, ou erreur renvoyée par le CLI.
    case failed(requestID: Int, message: String)
}
