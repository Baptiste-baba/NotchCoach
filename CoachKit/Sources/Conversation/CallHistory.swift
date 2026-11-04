/// Historique d'un call, tel que la notch l'affiche : les suggestions de Claude et les échecs, du plus ancien au plus
/// récent. Logique pure.
struct CallHistory {
    /// Entrées, de la plus ancienne à la plus récente. Rien n'est retiré pendant le call : la place d'une entrée lui
    /// sert d'identifiant.
    private(set) var entries: [CallDisplay.Entry] = []
    /// Suggestion en train de s'écrire : sa requête et sa place dans l'historique.
    private var writing: (requestID: Int, index: Int)?

    /// Texte de la suggestion de `requestID`, complet jusqu'ici : ajoutée en bas la première fois, mise à jour ensuite.
    mutating func showSuggestion(_ text: String, requestID: Int) {
        if let writing, writing.requestID == requestID {
            entries[writing.index].text = text
            return
        }
        writing = (requestID, entries.count)
        append(.suggestion, text)
    }

    /// Ajoute un échec en bas de l'historique.
    mutating func addFailure(_ text: String) {
        append(.failure, text)
    }

    private mutating func append(_ kind: CallDisplay.Entry.Kind, _ text: String) {
        entries.append(CallDisplay.Entry(id: entries.count, kind: kind, text: text))
    }
}
