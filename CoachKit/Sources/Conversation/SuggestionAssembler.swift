/// Assemble la suggestion à afficher à partir des morceaux de réponse de Claude, sans jamais montrer la réponse
/// convenue « - » (rien à suggérer). Logique pure.
struct SuggestionAssembler {
    /// Nouvelle requête : la suggestion repart de zéro, et les morceaux des requêtes précédentes sont ignorés.
    mutating func start(requestID: Int) {
        fatalError("TODO")
    }

    /// Ajoute un morceau de réponse. Renvoie le texte complet à afficher, ou `nil` s'il n'y a rien à montrer :
    /// texte encore vide ou réduit à « - », ou morceau d'une requête obsolète.
    mutating func append(_ text: String, requestID: Int) -> String? {
        fatalError("TODO")
    }

    /// Fin de la réponse. Renvoie le texte final, ou `nil` si Claude n'a rien suggéré (« - » ou réponse vide).
    mutating func finish(requestID: Int) -> String? {
        fatalError("TODO")
    }
}
