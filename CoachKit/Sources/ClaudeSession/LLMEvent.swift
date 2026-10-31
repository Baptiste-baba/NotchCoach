/// Ce que la session émet, uniquement pour la requête la plus récente.
public enum LLMEvent: Equatable, Sendable {
    /// Nouveau morceau de texte de la réponse, à afficher à la suite des précédents.
    case delta(requestID: Int, text: String)
    /// La réponse est complète.
    case finished(requestID: Int)
}
