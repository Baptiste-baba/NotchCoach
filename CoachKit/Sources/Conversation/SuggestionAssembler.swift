/// Assemble la suggestion à afficher à partir des morceaux de réponse de Claude, sans jamais montrer la réponse
/// convenue « - » (rien à suggérer). Logique pure.
struct SuggestionAssembler {
    /// Requête dont la réponse est en cours ; les morceaux des autres sont ignorés.
    private var requestID: Int?
    private var text = ""

    /// Nouvelle requête : la suggestion repart de zéro, et les morceaux des requêtes précédentes sont ignorés.
    mutating func start(requestID: Int) {
        self.requestID = requestID
        text = ""
    }

    /// Ajoute un morceau de réponse. Renvoie le texte complet à afficher, ou `nil` s'il n'y a rien à montrer :
    /// texte encore vide ou réduit à « - », ou morceau d'une requête obsolète.
    mutating func append(_ text: String, requestID: Int) -> String? {
        guard requestID == self.requestID else { return nil }
        self.text += text
        return displayableText
    }

    /// Fin de la réponse. Renvoie le texte final, ou `nil` si Claude n'a rien suggéré (« - » ou réponse vide).
    mutating func finish(requestID: Int) -> String? {
        guard requestID == self.requestID else { return nil }
        self.requestID = nil
        return displayableText
    }

    /// Tant que la réponse n'est que « - », on ne sait pas encore si c'est le début d'une suggestion : rien à montrer.
    private var displayableText: String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "-" ? nil : trimmed
    }
}
